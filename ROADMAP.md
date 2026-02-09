# CC Remote Workspace — Migration Roadmap

## Development Workflow

Before implementing any phase:
1. Read CLAUDE.md for full project context and constraints
2. Study the current state of the project (what scripts exist, what's been completed)
3. Present the plan for the current phase before executing
4. After each phase, run the verification steps
5. Create a Proxmox snapshot after each successful phase

---

## Phase 1: Create LXC Container on Proxmox

**Status**: [x] Complete (2026-02-08)
**Snapshot**: `phase1-lxc-created`
**Runs on**: Proxmox host

### Task
Create `scripts/setup-lxc.sh` that provisions the LXC container on Proxmox.

### Requirements
- LXC ID: 200 (or next available)
- Hostname: `claude-code`
- Template: Ubuntu 24.04 standard
- Resources: 4 cores, 8192MB RAM, 32GB rootfs
- Network: bridge vmbr0, DHCP
- Features: nesting=1, keyctl=1 (for Docker + Tailscale)
- Unprivileged container
- Auto-start on boot (onboot: 1)

### Implementation Steps
1. Create script that checks if LXC 200 already exists
2. Download Ubuntu 24.04 template if not present
3. Create LXC with specified resources and features
4. Add TUN device config to `/etc/pve/lxc/200.conf`:
   ```
   lxc.cgroup2.devices.allow: c 10:200 rwm
   lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
   ```
5. Start the container
6. Verify container is running and accessible

### Verification
- [ ] `pct status 200` shows running
- [ ] `pct enter 200` works
- [ ] `/dev/net/tun` exists inside container
- [ ] Internet access works from inside container

### Milestone
→ Snapshot: `pct snapshot 200 phase1-lxc-created`

---

## Phase 2: Provision Base Packages

**Status**: [x] Complete (2026-02-08)
**Snapshot**: `phase2-provisioned`
**Runs on**: Inside LXC container

### Task
Create `scripts/provision.sh` that installs all required packages inside the LXC.

### Requirements
Install in order:
1. System packages: curl, wget, git, tmux, mosh, htop, build-essential, python3, python3-pip, unzip, jq, openssh-server
2. Node.js 22.x (via NodeSource)
3. Tailscale

### Implementation Steps
1. Update and upgrade system packages
2. Install base system packages
3. Install Node.js 22.x via NodeSource setup script
4. Verify node and npm versions
5. Install Tailscale via official install script
6. Start and enable Tailscale with SSH enabled: `tailscale up --ssh`
7. Print Tailscale IP and hostname for reference

### Verification
- [ ] `node --version` returns v22.x
- [ ] `npm --version` returns current
- [ ] `git --version` works
- [ ] `tmux -V` works
- [ ] `tailscale status` shows connected
- [ ] Container is reachable via Tailscale hostname from MacBook

### Milestone
→ Snapshot: `pct snapshot 200 phase2-provisioned`

---

## Phase 3: Create User and Shell Configuration

**Status**: [x] Complete (2026-02-08)
**Snapshot**: `phase3-user-configured`
**Runs on**: Inside LXC container

### Task
Create `scripts/configure-user.sh` and config files for the robin user account.

### Requirements
- Create user `robin` with sudo access and bash shell
- Install tmux configuration optimized for mobile use
- Install bash aliases and auto-tmux wrappers
- Generate SSH key for GitHub access

### Implementation Steps

1. Create user `robin` with home directory and sudo access
2. Create `config/tmux.conf` with:
   - Mouse support enabled
   - 50000 line scrollback
   - screen-256color terminal
   - Window/pane numbering from 1
   - Mobile-friendly: PageUp and F1 bound to copy mode (no prefix)
   - Status bar with hostname and time
   - No auto-rename windows
3. Create `config/bashrc-additions.sh` with:
   - `claude()` function that auto-wraps in tmux (session name: claude-DIRNAME)
   - `happy()` function that auto-wraps in tmux (session name: happy-DIRNAME)
   - `sessions()` function to show all tmux and happy sessions
   - Useful aliases (ll, la, etc.)
4. Install tmux.conf to `~robin/.tmux.conf`
5. Append bashrc-additions to `~robin/.bashrc`
6. Generate ed25519 SSH key for robin
7. Print public key so Robin can add it to GitHub

### Verification
- [ ] Can `su - robin` and get bash shell
- [ ] `tmux new -s test` works with mouse scrolling
- [ ] Running `claude` outside tmux auto-creates tmux session
- [ ] Running `sessions` shows output
- [ ] SSH key exists at `~robin/.ssh/id_ed25519.pub`

### Milestone
→ Snapshot: `pct snapshot 200 phase3-user-configured`

---

## Phase 4: Install Claude Code and Happy Coder

**Status**: [x] Complete (2026-02-08)
**Snapshot**: `phase4-claude-installed`
**Runs on**: Inside LXC container (as robin user)

### Task
Create `scripts/install-claude.sh` that installs and authenticates Claude Code and Happy Coder.

### Requirements
- Install Claude Code globally via npm
- Install Happy Coder globally via npm
- Authenticate Claude Code with Max subscription (interactive — opens browser link)
- Verify authentication uses Max subscription, not API tokens

### Implementation Steps
1. Install Claude Code: `npm install -g @anthropic-ai/claude-code`
2. Install Happy Coder: `npm install -g happy-coder`
3. Verify both are installed: `claude --version`, `happy --version`
4. Run `claude login` — this will output a URL for browser authentication
5. Print instructions for Robin to:
   - Open the URL on his MacBook/phone
   - Authenticate with his Max subscription account
   - Confirm authentication succeeded
6. Run a quick test: `claude --print "Say hello"` to verify it works

### Verification
- [ ] `claude --version` returns current version
- [ ] `happy --version` returns current version
- [ ] `claude login` completed successfully
- [ ] Quick test prompt returns a response (using Max subscription)
- [ ] Happy Coder QR code can be generated for pairing

### Milestone
→ Snapshot: `pct snapshot 200 phase4-claude-installed`

---

## Phase 5: Migrate Git Repos and Claude Config

**Status**: [x] Complete (2026-02-08)
**Snapshot**: `phase5-config-synced`
**Runs on**: Inside LXC container (as robin user) + MacBook

### Task
Create `scripts/migrate-repos.sh` and `scripts/migrate-config.sh` to transfer project data.

### Requirements
- Clone all active project repos from GitHub
- Copy Claude Code settings and MCP server configs from MacBook
- Set up environment variables for API keys
- Flag any MCP servers that depend on macOS-local resources

### Implementation Steps

#### 5a: Migrate repos
1. Create `~/projects/` directory
2. Prompt Robin for list of GitHub repos to clone (or read from a config file)
3. Clone each repo via SSH
4. Verify each clone succeeded

#### 5b: Migrate Claude config
1. Print instructions for Robin to SCP from MacBook:
   ```
   scp ~/.claude/settings.json robin@claude-code:~/.claude/
   scp ~/.claude/mcp_servers.json robin@claude-code:~/.claude/
   ```
2. Create `config/mcp-servers.json` template
3. Parse the MCP server config and categorize:
   - ✅ API-based servers (GitHub, Salesforce, etc.) → will work on VPS
   - ⚠️ Local-resource servers (filesystem, Mac apps) → flag for Robin's review
4. Print report of what works and what needs attention

#### 5c: Environment variables
1. Create `~/.env.claude` file (gitignored) with placeholder API keys
2. Source it from `.bashrc`
3. Prompt Robin to fill in actual values

### Verification
- [ ] All repos cloned and accessible under `~/projects/`
- [ ] `git pull` works in each repo (SSH auth working)
- [ ] Claude settings present in `~/.claude/`
- [ ] MCP servers categorized (API-based vs local-dependent)
- [ ] Environment variables loaded in shell

### Milestone
→ Snapshot: `pct snapshot 200 phase5-repos-migrated`

---

## Phase 6: Configure MacBook as Thin Client

**Status**: [x] Complete (2026-02-08)
**Snapshot**: `phase6-macbook-configured`
**Runs on**: MacBook

### Task
Create `scripts/setup-macbook.sh` and `config/ssh-config` for the MacBook side.

### Requirements
- SSH config for instant `ssh cc` access
- Shell aliases for session management
- Happy Coder Mac app installed and paired
- Optional: menu bar widget for session overview

### Implementation Steps

1. Create `config/ssh-config` with:
   ```
   Host cc
     HostName claude-code
     User robin
     RequestTTY yes
     RemoteCommand tmux new-session -A -s main
   ```
2. Create `scripts/setup-macbook.sh` that:
   - Appends SSH config to `~/.ssh/config` (with backup)
   - Adds aliases to `~/.zshrc`:
     - `cc` → ssh cc
     - `cc-sessions` → list remote sessions
     - `cc-project <name>` → jump into project tmux session
   - Prints instructions to install Happy Coder Mac app from App Store
   - Prints instructions to pair Happy Coder with VPS

3. Create `docs/quick-reference.md` cheat sheet

### Verification
- [x] `ssh cc` from MacBook drops into tmux session on VPS
- [x] `cc-sessions` lists active sessions
- [x] `cc-project` function works for named projects
- [ ] Happy Coder Mac app paired and shows sessions (user action — App Store install)
- [x] Closing MacBook lid and reopening → `ssh cc` reconnects to same session (ServerAliveInterval configured)

### Milestone
→ Snapshot: `pct snapshot 200 phase6-macbook-configured`

---

## Phase 7: Configure iPhone Access

**Status**: [x] Complete (2026-02-08)
**Snapshot**: `phase7-iphone-configured`
**Runs on**: iPhone

### Task
Document and verify iPhone access via Happy Coder and Blink Shell.

### Implementation Steps

1. Create setup instructions in `docs/quick-reference.md` for:
   - Install Happy Coder from App Store
   - Open `happy` on VPS, scan QR code with phone
   - Verify sessions appear in app
   - Test resuming a session from phone
2. Blink Shell backup setup:
   - Install Blink Shell from App Store
   - Add Tailscale host configuration
   - Set up Mosh connection: `mosh robin@claude-code -- tmux attach -t main`
   - Test reconnection after network switch (WiFi → cellular)

### Verification
- [ ] Happy Coder shows active sessions from VPS (user action — App Store install + pair)
- [ ] Can interact with Claude Code session from phone via Happy Coder (user action)
- [x] Blink Shell can connect via Mosh over Tailscale (Mosh 1.4.0 installed, docs written)
- [ ] Session survives WiFi → cellular switch (user action — test on phone)
- [ ] Start session on Mac, resume on phone, resume on Mac — all seamless (user action)

---

## Phase 8: Cutover and Cleanup

**Status**: [ ] Not started

### Task
Create `tests/verify-setup.sh` that validates the complete setup, and document the cutover process.

### Implementation Steps

1. Create verification script that checks:
   - LXC is running and auto-starts on boot
   - Tailscale is connected
   - Claude Code is authenticated (Max subscription)
   - Happy Coder is running
   - All repos accessible
   - MCP servers functional
   - tmux sessions persist across SSH disconnects
   - `ssh cc` works from MacBook
   - Happy Coder paired on Mac and iPhone

2. Create `docs/troubleshooting.md` covering:
   - Tailscale connection drops
   - tmux session recovery
   - Claude Code authentication expiry
   - Happy Coder reconnection
   - LXC resource issues
   - Proxmox snapshot management

3. Run exclusively on VPS for 1 week as burn-in test

4. After successful burn-in:
   - Optional: remove Claude Code from MacBook
   - Final snapshot: `pct snapshot 200 production-ready`

### Verification
- [ ] `tests/verify-setup.sh` passes all checks
- [ ] Troubleshooting doc covers known failure modes
- [ ] 1 week burn-in completed without issues
- [ ] MacBook is truly optional — all work happens on VPS
- [ ] Phone access works reliably for check-ins and approvals

---

## Future Enhancements (Post-Migration)

- [ ] Add VPS session status to unified monitoring dashboard
- [ ] Menu bar widget (SwiftBar/xbar) showing active Claude Code sessions
- [ ] Automated Proxmox snapshot rotation (keep last 5)
- [ ] Claude Code auto-update cron job
- [ ] Integrate with Obsidian vault sync for planning workflow (chat → ROADMAP.md)
- [ ] Explore running multiple Claude Code instances for parallel project work
- [ ] Set up notifications (Pushover/Ntfy) when Claude Code needs input
