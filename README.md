# CC Remote Workspace

> Run Claude Code as an always-on service on a Proxmox LXC — accessible from MacBook, iPhone, or browser via SSH/tmux and Happy Coder over Tailscale.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform: Proxmox](https://img.shields.io/badge/Platform-Proxmox%20VE-orange.svg)](https://www.proxmox.com/)
[![OS: Ubuntu 24.04](https://img.shields.io/badge/OS-Ubuntu%2024.04-E95420.svg)](https://ubuntu.com/)
[![Network: Tailscale](https://img.shields.io/badge/Network-Tailscale-0052FF.svg)](https://tailscale.com/)

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
- [Usage](#usage)
- [Project Structure](#project-structure)
- [Configuration](#configuration)
- [Roadmap](#roadmap)
- [License](#license)

## Overview

This project decouples Claude Code from a local machine by running it on a dedicated Proxmox LXC container. The container is always on, persistent, and accessible from any device through multiple access paths. No more losing sessions when you close your laptop.

**The problem:** Claude Code sessions are tied to your terminal. Close the lid, lose the session. Switch devices, start over.

**The solution:** Run Claude Code on a headless server with tmux for session persistence. Access it from anywhere via SSH (MacBook), Happy Coder (iPhone/Mac), or Mosh (unreliable networks).

## Architecture

```
Proxmox Host
└── LXC 200: claude-code (Ubuntu 24.04)
    ├── Claude Code (authenticated with Max subscription)
    ├── Happy Coder CLI (session relay to phone/mac)
    ├── tmux (session persistence)
    ├── Tailscale (encrypted P2P mesh networking)
    ├── Git repos (cloned from GitHub)
    └── Node.js 22.x runtime

Access paths:
  iPhone  → Happy Coder app  → relay → LXC
  iPhone  → Blink Shell/Mosh → Tailscale → LXC
  MacBook → Happy Coder Mac  → relay → LXC
  MacBook → Ghostty SSH      → Tailscale → LXC
  Browser → Happy Coder web  → relay → LXC
```

## Features

- **Always-on Claude Code** — runs on a Proxmox LXC, survives reboots (`onboot: 1`)
- **Session persistence** — tmux keeps sessions alive across disconnects
- **Multi-device access** — MacBook, iPhone, browser — all hit the same session
- **One-command access** — `ssh cc` from MacBook drops straight into tmux
- **Happy Coder relay** — interact with Claude Code from your phone
- **Tailscale networking** — encrypted P2P mesh, no port forwarding needed
- **Idempotent scripts** — every script is safe to run multiple times
- **Phased migration** — 8 independent phases, each with snapshots for rollback

## Prerequisites

- [Proxmox VE](https://www.proxmox.com/) host with LXC support
- [Tailscale](https://tailscale.com/) account with Tailscale installed on your devices
- Claude [Max subscription](https://claude.ai/) (all usage goes through Max, not API tokens)
- macOS with zsh (for MacBook thin-client setup)

## Getting Started

The setup is split into phases. Each phase has its own script and creates a Proxmox snapshot for easy rollback.

### Phase 1: Create the LXC Container

Run **on the Proxmox host**:

```bash
bash scripts/setup-lxc.sh
```

This creates an unprivileged Ubuntu 24.04 LXC with:
- 4 cores, 8 GB RAM, 32 GB disk
- Tailscale TUN device pre-configured
- Nesting enabled (for Docker compatibility)
- Auto-start on boot

After success, snapshot:

```bash
pct snapshot 200 phase1-lxc-created
```

### Phase 6: Configure MacBook as Thin Client

Run **on your MacBook**:

```bash
bash scripts/setup-macbook.sh
```

This installs SSH config and shell aliases for instant VPS access. See [Usage](#usage) for the full command reference.

> Phases 2–5 and 7–8 are documented in [ROADMAP.md](ROADMAP.md) and will be added as the project progresses.

## Usage

After running `setup-macbook.sh` and sourcing your shell:

```bash
source ~/.zshrc
```

### Quick Commands

| Command | Description |
|---|---|
| `cc` | SSH into default tmux session on VPS |
| `cc-sessions` | List all active tmux sessions on VPS |
| `cc-project <name>` | Attach/create a named project session |
| `cc-claude [dir]` | Start Claude Code (optionally in a project dir) |
| `cc-happy [dir]` | Start Happy Coder for phone relay |

### Examples

```bash
# Jump into your main session
cc

# Work on a specific project
cc-project my-api

# Start Claude Code in a project
cc-claude my-api

# Start Happy Coder so you can continue from your phone
cc-happy my-api

# Check what's running
cc-sessions
```

### Session Lifecycle

1. Start a session from MacBook: `cc` or `cc-project myproject`
2. Close the lid — session stays alive on the VPS
3. Reopen and reconnect: same command, same session
4. Switch to iPhone via Happy Coder — same Claude Code session
5. Come back to MacBook — `cc` picks up right where you left off

## Project Structure

```
cc-remote-workspace/
├── README.md                  # This file
├── CLAUDE.md                  # Project context for Claude Code
├── ROADMAP.md                 # Migration phases and task tracking
├── LICENSE                    # MIT License
├── scripts/
│   ├── setup-lxc.sh           # Phase 1: Proxmox LXC creation (runs on host)
│   └── setup-macbook.sh       # Phase 6: MacBook thin-client setup (runs on Mac)
└── config/
    └── ssh-config             # SSH config snippet for 'ssh cc' access
```

## Configuration

### LXC Container (ID 200)

| Setting | Value |
|---|---|
| Hostname | `claude-code` |
| OS | Ubuntu 24.04 |
| Cores | 4 |
| Memory | 8192 MB |
| Disk | 32 GB (local-lvm) |
| Network | DHCP on vmbr0 |
| Features | nesting=1, keyctl=1 |
| TUN device | Mounted for Tailscale |
| Auto-start | Yes |

### SSH Hosts

| Host | Purpose |
|---|---|
| `cc` | Auto-attaches to tmux `main` session |
| `cc-raw` | Plain SSH for scripting, scp, rsync |

Both resolve `claude-code` via Tailscale DNS.

## Roadmap

See [ROADMAP.md](ROADMAP.md) for the full 8-phase migration plan:

- [x] **Phase 1** — Create LXC container on Proxmox
- [ ] **Phase 2** — Provision base packages (Node.js, Tailscale, tmux)
- [ ] **Phase 3** — Create user and shell configuration
- [ ] **Phase 4** — Install Claude Code and Happy Coder
- [ ] **Phase 5** — Migrate Git repos and Claude config
- [x] **Phase 6** — Configure MacBook as thin client
- [ ] **Phase 7** — Configure iPhone access
- [ ] **Phase 8** — Cutover and cleanup

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
