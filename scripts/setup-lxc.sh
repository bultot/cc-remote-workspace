#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# setup-lxc.sh — Create LXC 200 for Claude Code on Proxmox
# =============================================================================
#
#   THIS SCRIPT RUNS ON THE PROXMOX HOST (not inside the LXC)
#
#   Usage:  bash scripts/setup-lxc.sh
#
#   What it does:
#     1. Downloads Ubuntu 24.04 template if missing
#     2. Creates unprivileged LXC 200 with 4c/8GB/32GB
#     3. Adds TUN device config for Tailscale
#     4. Starts the container and verifies networking
#
#   Idempotent: safe to run multiple times — skips creation if LXC 200 exists.
# =============================================================================

# --- Constants ---------------------------------------------------------------

CTID=200
HOSTNAME="claude-code"
STORAGE="local-lvm"
TEMPLATE_STORAGE="local"
CORES=4
MEMORY=8192
SWAP=1024
DISK=32
BRIDGE="vmbr0"
LXC_CONF="/etc/pve/lxc/${CTID}.conf"

# --- Helpers -----------------------------------------------------------------

info()  { echo -e "\033[1;34m[INFO]\033[0m  $*"; }
ok()    { echo -e "\033[1;32m[OK]\033[0m    $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
fail()  { echo -e "\033[1;31m[FAIL]\033[0m  $*"; exit 1; }

# --- Step 1: Prerequisite check ----------------------------------------------

info "Checking prerequisites..."

if ! command -v pct &>/dev/null; then
    fail "pct command not found. This script must run on a Proxmox host."
fi

if ! command -v pveam &>/dev/null; then
    fail "pveam command not found. Is this a Proxmox VE installation?"
fi

ok "Running on Proxmox host"

# --- Step 2: Idempotency guard -----------------------------------------------

info "Checking if LXC ${CTID} already exists..."

if pct status "${CTID}" &>/dev/null; then
    STATUS=$(pct status "${CTID}" | awk '{print $2}')
    IP=$(pct exec "${CTID}" -- hostname -I 2>/dev/null | awk '{print $1}' || echo "unknown")
    warn "LXC ${CTID} already exists (status: ${STATUS}, IP: ${IP})"
    warn "Nothing to do. Delete it first if you want to recreate:"
    warn "  pct stop ${CTID} && pct destroy ${CTID}"
    exit 0
fi

ok "LXC ${CTID} does not exist — proceeding with creation"

# --- Step 3: Template download -----------------------------------------------

info "Checking for Ubuntu 24.04 template..."

# Update the template catalog
pveam update >/dev/null 2>&1 || warn "Could not update template catalog (offline?)"

# Find the Ubuntu 24.04 standard template
TEMPLATE=$(pveam available --section system | awk '/ubuntu-24.04-standard.*amd64/ {print $2}' | sort -V | tail -1)

if [[ -z "${TEMPLATE}" ]]; then
    fail "Could not find Ubuntu 24.04 standard template in pveam catalog"
fi

info "Template: ${TEMPLATE}"

# Check if already downloaded
if pveam list "${TEMPLATE_STORAGE}" | grep -q "${TEMPLATE}"; then
    ok "Template already downloaded"
else
    info "Downloading template (this may take a minute)..."
    pveam download "${TEMPLATE_STORAGE}" "${TEMPLATE}"
    ok "Template downloaded"
fi

# --- Step 4: Create container ------------------------------------------------

info "Creating LXC ${CTID} (${HOSTNAME})..."

pct create "${CTID}" "${TEMPLATE_STORAGE}:vztmpl/${TEMPLATE}" \
    --hostname "${HOSTNAME}" \
    --ostype ubuntu \
    --storage "${STORAGE}" \
    --rootfs "${STORAGE}:${DISK}" \
    --cores "${CORES}" \
    --memory "${MEMORY}" \
    --swap "${SWAP}" \
    --net0 "name=eth0,bridge=${BRIDGE},ip=dhcp" \
    --features "nesting=1,keyctl=1" \
    --unprivileged 1 \
    --onboot 1 \
    --start 0

ok "LXC ${CTID} created (not started yet — need TUN config first)"

# --- Step 5: TUN device config -----------------------------------------------

info "Adding TUN device configuration for Tailscale..."

TUN_CGROUP="lxc.cgroup2.devices.allow: c 10:200 rwm"
TUN_MOUNT="lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file"

# Only append if not already present (idempotent)
if ! grep -qF "${TUN_CGROUP}" "${LXC_CONF}" 2>/dev/null; then
    echo "" >> "${LXC_CONF}"
    echo "# TUN device for Tailscale" >> "${LXC_CONF}"
    echo "${TUN_CGROUP}" >> "${LXC_CONF}"
    echo "${TUN_MOUNT}" >> "${LXC_CONF}"
    ok "TUN config added to ${LXC_CONF}"
else
    ok "TUN config already present in ${LXC_CONF}"
fi

# --- Step 6: Start container -------------------------------------------------

info "Starting LXC ${CTID}..."
pct start "${CTID}"
ok "Start command issued"

# --- Step 7: Wait for boot ---------------------------------------------------

info "Waiting for container to boot..."
sleep 5

STATUS=$(pct status "${CTID}" | awk '{print $2}')
if [[ "${STATUS}" != "running" ]]; then
    fail "Container is not running (status: ${STATUS})"
fi

ok "Container is running"

# --- Step 8: Verify TUN device -----------------------------------------------

info "Verifying /dev/net/tun inside container..."

if pct exec "${CTID}" -- test -e /dev/net/tun; then
    ok "/dev/net/tun exists"
else
    fail "/dev/net/tun not found inside container — check LXC conf"
fi

# --- Step 9: Verify networking -----------------------------------------------

info "Verifying internet connectivity..."

# Give the network a moment to come up
sleep 3

if pct exec "${CTID}" -- ping -c 1 -W 5 1.1.1.1 >/dev/null 2>&1; then
    ok "Internet connectivity works"
else
    warn "Ping to 1.1.1.1 failed — network may still be initializing"
    warn "Try manually: pct exec ${CTID} -- ping -c 1 1.1.1.1"
fi

# --- Step 10: Summary --------------------------------------------------------

IP=$(pct exec "${CTID}" -- hostname -I 2>/dev/null | awk '{print $1}' || echo "pending")

echo ""
echo "============================================================"
echo "  LXC ${CTID} (${HOSTNAME}) — Ready"
echo "============================================================"
echo ""
echo "  Status:    running"
echo "  IP:        ${IP}"
echo "  Cores:     ${CORES}"
echo "  Memory:    ${MEMORY} MB"
echo "  Disk:      ${DISK} GB"
echo "  Features:  nesting=1, keyctl=1"
echo "  TUN:       /dev/net/tun mounted"
echo "  Autostart: yes"
echo ""
echo "  Next steps:"
echo "    1. Verify:  pct enter ${CTID}"
echo "    2. Snapshot: pct snapshot ${CTID} phase1-lxc-created"
echo "    3. Run Phase 2: bash scripts/provision.sh"
echo ""
echo "============================================================"
