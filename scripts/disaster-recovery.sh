#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# disaster-recovery.sh — Rebuild LXC 200 (Claude Code) from scratch
# =============================================================================
#
#   THIS SCRIPT RUNS ON THE PROXMOX HOST (not inside the LXC)
#
#   LXC 200 is stateless — all state lives in Git repos (GitHub) and shared
#   config (Syncthing from MacBook). Recovery means re-creating the container
#   and re-running the provisioning scripts. No backup restore needed.
#
#   Recovery sources:
#     - Git repos        → cloned from GitHub
#     - Claude config    → synced from MacBook via Syncthing
#     - Shell config     → embedded in provisioning scripts
#     - Credentials      → 1Password (re-auth required)
#
#   PREREQUISITES:
#     1. Proxmox VE host with this repo cloned
#     2. Internet connectivity (for package installs + GitHub)
#     3. MacBook with Syncthing running (for config re-sync after recovery)
#
#   USAGE:
#     1. Clone this repo on the Proxmox host:
#        git clone https://github.com/bultot/claude-setup.git
#     2. Run:
#        bash claude-setup/scripts/disaster-recovery.sh
#     3. Follow the manual steps printed at the end
#
#   WHAT THIS DOES:
#     Phase 1: Creates LXC 200 (setup-lxc.sh)
#     Phase 2: Provisions packages, Node.js, Tailscale, Zellij (provision.sh)
#     Phase 3: Configures robin user, shell, Zellij layouts (configure-user.sh)
#     Phase 4: Installs Claude Code + Happy Coder (install-claude.sh)
#     Phase 5: Clones repos from GitHub
#     Phase 6: Installs Happy Coder systemd service
#     Verify:  Runs verification checks
#
#   DURATION: ~10-15 minutes (mostly package downloads)
#
#   WARNING: If LXC 200 already exists, this script will ask before destroying
#            it. All data inside LXC 200 will be lost.
# =============================================================================

# --- Constants ---------------------------------------------------------------

CTID=200
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
USERNAME="robin"

# --- Helpers -----------------------------------------------------------------

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${CYAN}[$(date '+%H:%M:%S')]${NC} $*"; }
ok()      { echo -e "${GREEN}[$(date '+%H:%M:%S')] ✓${NC} $*"; }
warn()    { echo -e "${YELLOW}[$(date '+%H:%M:%S')] WARNING:${NC} $*"; }
error()   { echo -e "${RED}[$(date '+%H:%M:%S')] ERROR:${NC} $*" >&2; }
section() { echo -e "\n${BOLD}${CYAN}═══ $* ═══${NC}\n"; }

# --- Pre-flight checks -------------------------------------------------------

section "Pre-flight checks"

if ! command -v pct &>/dev/null; then
    error "pct command not found. This script must run on a Proxmox VE host."
    exit 1
fi
ok "Running on Proxmox host"

if [[ ! -f "${SCRIPT_DIR}/setup-lxc.sh" ]]; then
    error "Cannot find setup-lxc.sh in ${SCRIPT_DIR}"
    error "Make sure you're running from the claude-setup repo."
    exit 1
fi
ok "Found provisioning scripts in ${SCRIPT_DIR}"

# Check internet connectivity
if ping -c 1 -W 5 1.1.1.1 &>/dev/null; then
    ok "Internet connectivity"
else
    warn "Cannot reach 1.1.1.1 — package installs may fail"
fi

# --- Handle existing LXC 200 ------------------------------------------------

if pct status "${CTID}" &>/dev/null; then
    STATUS=$(pct status "${CTID}" | awk '{print $2}')
    warn "LXC ${CTID} already exists (status: ${STATUS})"
    echo ""
    read -p "  Destroy existing LXC ${CTID} and rebuild from scratch? [y/N] " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        info "Aborted. LXC ${CTID} not modified."
        exit 0
    fi
    info "Stopping and destroying LXC ${CTID}..."
    pct stop "${CTID}" 2>/dev/null || true
    sleep 2
    pct destroy "${CTID}" --purge
    ok "LXC ${CTID} destroyed"
fi

# --- Phase 1: Create LXC ----------------------------------------------------

section "Phase 1: Create LXC ${CTID}"
bash "${SCRIPT_DIR}/setup-lxc.sh"
ok "Phase 1 complete — LXC ${CTID} created"

# --- Phase 2: Provision (inside LXC as root) ---------------------------------

section "Phase 2: Provision base packages"
info "Copying provision.sh into LXC..."
pct push "${CTID}" "${SCRIPT_DIR}/provision.sh" /root/provision.sh
pct exec "${CTID}" -- bash /root/provision.sh
ok "Phase 2 complete — packages, Node.js, Tailscale, Zellij installed"

# --- Phase 3: Configure user (inside LXC as root) ---------------------------

section "Phase 3: Configure user"
info "Copying configure-user.sh into LXC..."
pct push "${CTID}" "${SCRIPT_DIR}/configure-user.sh" /root/configure-user.sh
pct exec "${CTID}" -- bash /root/configure-user.sh
ok "Phase 3 complete — robin user, shell, Zellij config"

# --- Phase 4: Install Claude Code + Happy Coder (as robin) ------------------

section "Phase 4: Install Claude Code + Happy Coder"
info "Copying install-claude.sh into LXC..."
pct push "${CTID}" "${SCRIPT_DIR}/install-claude.sh" /home/${USERNAME}/install-claude.sh
pct exec "${CTID}" -- chown "${USERNAME}:${USERNAME}" /home/${USERNAME}/install-claude.sh
pct exec "${CTID}" -- su - "${USERNAME}" -c "bash ~/install-claude.sh"
ok "Phase 4 complete — Claude Code + Happy Coder installed"

# --- Phase 5: Clone repos from GitHub ---------------------------------------

section "Phase 5: Clone repos from GitHub"

REPOS=(
    "bultot/claude-setup"
    "bultot/homeserver"
    "bultot/homeassistant"
    "bultot/career-os"
    "bultot/bultot.nl"
    "bultot/expensify-os"
    "bultot/inbox-co-pilot"
    "bultot/auto-trading-bot"
    "bultot/reminders-cli"
    "bultot/todo-voice"
)

info "Cloning ${#REPOS[@]} repos into ~/projects/personal/..."
pct exec "${CTID}" -- su - "${USERNAME}" -c "mkdir -p ~/projects/personal"

for repo in "${REPOS[@]}"; do
    repo_name="${repo#*/}"
    info "  Cloning ${repo_name}..."
    pct exec "${CTID}" -- su - "${USERNAME}" -c \
        "git clone --quiet git@github.com:${repo}.git ~/projects/personal/${repo_name} 2>/dev/null || echo 'SKIP: ${repo_name} (may need SSH key added to GitHub)'"
done
ok "Phase 5 complete — repos cloned"

# --- Phase 6: Install Happy Coder systemd service ---------------------------

section "Phase 6: Happy Coder systemd service"
info "Installing Happy Coder service..."
pct push "${CTID}" "${REPO_DIR}/config/happy-coder.service" /tmp/happy-coder.service
pct exec "${CTID}" -- su - "${USERNAME}" -c "
    mkdir -p ~/.config/systemd/user
    cp /tmp/happy-coder.service ~/.config/systemd/user/
    systemctl --user daemon-reload
    systemctl --user enable happy-coder 2>/dev/null || true
    systemctl --user start happy-coder 2>/dev/null || true
"
# Enable linger so user services run without login
pct exec "${CTID}" -- loginctl enable-linger "${USERNAME}" 2>/dev/null || true
ok "Phase 6 complete — Happy Coder service installed"

# --- Phase 7: Verification --------------------------------------------------

section "Verification"
info "Running basic health checks..."
echo ""

check() {
    local name="$1"
    local cmd="$2"
    if pct exec "${CTID}" -- su - "${USERNAME}" -c "$cmd" &>/dev/null; then
        echo -e "  ${GREEN}✓${NC}  ${name}"
    else
        echo -e "  ${RED}✗${NC}  ${name}"
    fi
}

check "Node.js"          "node --version"
check "Zellij"           "command -v zellij"
check "Claude Code"      "command -v claude"
check "Happy Coder"      "command -v happy"
check "git"              "git --version"
check "Tailscale"        "command -v tailscale"
check "Zellij config"    "test -f ~/.config/zellij/config.kdl"
check "SSH key"          "test -f ~/.ssh/id_ed25519"

echo ""

# --- Manual steps ------------------------------------------------------------

section "Recovery complete — manual steps remaining"

echo "  ${BOLD}1. Authenticate Tailscale:${NC}"
echo "     pct exec ${CTID} -- tailscale up --ssh"
echo ""
echo "  ${BOLD}2. Add SSH key to GitHub:${NC}"
echo "     pct exec ${CTID} -- su - ${USERNAME} -c 'cat ~/.ssh/id_ed25519.pub'"
echo "     → Add at https://github.com/settings/keys"
echo ""
echo "  ${BOLD}3. Authenticate Claude Code:${NC}"
echo "     pct exec ${CTID} -- su - ${USERNAME} -c 'claude login'"
echo ""
echo "  ${BOLD}4. Set up Syncthing for config sync:${NC}"
echo "     - Install Syncthing on LXC: apt install syncthing"
echo "     - Start: systemctl --user enable --now syncthing"
echo "     - Pair with MacBook via Syncthing GUI (port 8384)"
echo "     - Share ~/.claude-shared/ folder"
echo "     - Run: ~/.claude-shared/restore-symlinks.sh"
echo ""
echo "  ${BOLD}5. Set up 1Password CLI:${NC}"
echo "     - Install: https://developer.1password.com/docs/cli/get-started/"
echo "     - Authenticate: op signin"
echo ""
echo "  ${BOLD}6. Pair Happy Coder on phone:${NC}"
echo "     pct exec ${CTID} -- su - ${USERNAME} -c 'screen -r happy-relay'"
echo "     → Scan QR code with Happy Coder app"
echo "     → Ctrl-A D to detach"
echo ""
echo "  ${BOLD}7. Create Proxmox snapshot:${NC}"
echo "     pct snapshot ${CTID} recovery-complete"
echo ""
echo "  ${BOLD}8. Run full verification:${NC}"
echo "     pct exec ${CTID} -- su - ${USERNAME} -c 'bash ~/projects/personal/claude-setup/tests/verify-setup.sh'"
echo ""

ok "Disaster recovery script finished."
