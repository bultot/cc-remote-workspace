# Claude Setup

> My personal way of working with Claude Code — always-on, multi-device, session-persistent.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform: Proxmox](https://img.shields.io/badge/Platform-Proxmox%20VE-orange.svg)](https://www.proxmox.com/)
[![OS: Ubuntu 24.04](https://img.shields.io/badge/OS-Ubuntu%2024.04-E95420.svg)](https://ubuntu.com/)
[![Network: Tailscale](https://img.shields.io/badge/Network-Tailscale-0052FF.svg)](https://tailscale.com/)

## Table of Contents

- [Why This Exists](#why-this-exists)
- [How I Work With Claude](#how-i-work-with-claude)
- [When to Use What](#when-to-use-what)
- [Architecture](#architecture)
- [Best Practices](#best-practices)
- [Daily Commands](#daily-commands)
- [Setup Guide](#setup-guide)
- [Project Structure](#project-structure)
- [License](#license)

## Why This Exists

Claude Code sessions are tied to your terminal. Close the lid, lose the session. Switch devices, start over. I wanted something better:

- **Start a session on my MacBook, continue on my iPhone** while walking the dog
- **Close the laptop, reopen hours later** — pick up exactly where I left off
- **Never lose work** because of a network hiccup or a battery dying
- **Same tools, same prompt, same config** everywhere

The solution: Claude Code runs on a dedicated server (Proxmox LXC), always on, always reachable. My MacBook and iPhone are just thin clients that connect to it.

## How I Work With Claude

### The Daily Flow

1. **Open terminal on MacBook** — the welcome dashboard shows project status, usage stats, and a suggestion for what to work on next
2. **`cc`** — one command drops me into the LXC via SSH + Zellij
3. **Work normally** — Claude Code runs on the server, tools and repos are all there
4. **Close the lid** — session stays alive on the server
5. **Open again** — `cc` reconnects to the exact same session
6. **Switch to iPhone** — Happy Coder app connects to the same Claude Code instance
7. **Back to MacBook** — `cc` picks up where the phone left off

### Config Stays in Sync

My Claude config (CLAUDE.md, custom commands, hooks) is synced in real-time between MacBook and LXC via [Syncthing](https://syncthing.net/). Edit a command on one machine, it appears on the other within seconds. The shell prompt (Starship), aliases, and dashboard are all shared too.

### The Welcome Dashboard

Every new shell shows a contextual dashboard:

- **MacBook**: Full dashboard with project activity, token usage, suggested next project, and LXC commands
- **LXC**: Lightweight banner with active Zellij sessions and local commands

The dashboard reads pre-rendered cache files so it loads in <50ms — no delay when opening a terminal.

## When to Use What

| Scenario | Where | Why |
|---|---|---|
| **Deep coding session** | LXC (via `cc`) | Persistent session, full tools, won't lose work |
| **Quick file edit** | Either | Both have the same repos and config |
| **On the go / iPhone** | LXC (via Happy Coder) | Phone connects to the always-on server |
| **Local macOS tools needed** | MacBook directly | Xcode, Simulator, macOS-only MCP servers |
| **Pair programming / screen share** | MacBook directly | Screen sharing works better locally |
| **Reviewing PRs / reading code** | Either | Both have `gh` CLI and git |

### Rule of Thumb

**Use the LXC for anything that takes more than 5 minutes.** If a session might be interrupted (closing the lid, switching devices, lunch break), run it on the LXC. The session survives anything short of a power outage.

**Use the MacBook directly** only when you need macOS-specific tools or are sharing your screen.

## Architecture

```
Proxmox Host (home server)
└── LXC 200: claude-code (Ubuntu 24.04, 4c/8GB/32GB)
    ├── Claude Code (Max subscription)
    ├── Happy Coder (persistent systemd service — always-on phone relay)
    ├── Zellij (session persistence, OSC 52 clipboard)
    ├── Tailscale (encrypted P2P mesh)
    ├── zsh + Starship (same prompt as MacBook)
    ├── 1Password CLI (service account for MCP credentials)
    └── 10 Git repos synced from GitHub

Access paths:
  MacBook → ssh cc             → Tailscale → Zellij session
  MacBook → ssh cc-raw         → Tailscale → plain shell
  iPhone  → Happy Coder app    → relay → Claude Code
  Browser → app.happy.engineering → relay → Claude Code

Config sync (real-time via Syncthing over Tailscale):
  ~/.claude-shared/
  ├── CLAUDE.md, commands/, hooks/    → symlinked into ~/.claude/
  ├── starship.toml                   → shared prompt config
  ├── zshrc-shared.sh                 → shared shell config
  └── bin/cc-dashboard, cc-cache-refresh  → dashboard scripts
```

## Best Practices

### Session Management

- **One session per project**: Use `cc-project my-api` to create named sessions. Don't pile everything into one session.
- **Detach, don't exit**: Press `Alt-d` in Zellij to detach. The session stays alive. `exit` kills it.
- **Name sessions meaningfully**: `cc-project career-os` is better than `cc-project test`.

### Config and Secrets

- **Never hardcode secrets** — use 1Password CLI (`op`) with service account tokens
- **Edit shared config on either machine** — Syncthing syncs `~/.claude-shared/` bidirectionally
- **Machine-specific config stays local** — `settings.json`, `settings.local.json`, MCP plugin paths differ per OS

### Project Tracking

- **Every project has a STATUS.md** — single source of truth for project health
- **The `/status` skill** reads all STATUS.md files and renders a dashboard
- **Update STATUS.md when you finish significant work** — it powers the welcome dashboard's suggestions

### When Things Break

- **Symlinks overwritten by Claude Code update?** Run `~/.claude-shared/restore-symlinks.sh`
- **Zellij session frozen?** `zellij kill-session <name>` and start fresh
- **Can't reach LXC?** Check Tailscale: `tailscale status` on both machines
- **Full troubleshooting guide**: [docs/troubleshooting.md](docs/troubleshooting.md)

## Daily Commands

### From MacBook

| Command | What it does |
|---|---|
| `cc` | SSH into LXC, attach to Zellij session |
| `cc-claude [dir]` | Run Claude Code on LXC in `~/projects/<dir>` |
| `cc-sessions` | List Zellij sessions on LXC |
| `cc-project <name>` | Attach/create a named Zellij session on LXC |

### On the LXC

| Command | What it does |
|---|---|
| `claude` | Start Claude Code (auto-creates Zellij session) |
| `sessions` | List Zellij + Happy Coder sessions |

### Zellij Shortcuts

| Key | Action |
|---|---|
| `Alt-d` | Detach from session (keeps it alive) |
| `Ctrl-s` | Scroll mode (navigate output history) |
| `Ctrl-p` | Pane management |
| `Ctrl-t` | Tab management |
| Select text | Auto-copied to clipboard (OSC 52) |

### Dashboard

| Command | What it does |
|---|---|
| `cc-dashboard --welcome` | Quick welcome banner (runs on shell startup) |
| `cc-dashboard --full` | Full dashboard with service health |
| `cc-cache-refresh` | Force-refresh dashboard cache |

> Happy Coder runs as a persistent systemd service on the LXC — no manual start needed. Pair your phone once via `screen -r happy-relay` on the LXC to scan the QR code.

## Setup Guide

The setup is split into 8 phases. Each phase has its own script and creates a Proxmox snapshot for rollback. See [ROADMAP.md](ROADMAP.md) for the full plan.

| Phase | Script | Runs on | What it does |
|---|---|---|---|
| 1 | `scripts/setup-lxc.sh` | Proxmox host | Create LXC container |
| 2 | `scripts/provision.sh` | LXC (as root) | Install Node.js, Tailscale, Zellij, git, gh |
| 3 | `scripts/configure-user.sh` | LXC (as root) | Create user, zsh, Zellij config, shell aliases |
| 4 | `scripts/install-claude.sh` | LXC (as robin) | Install Claude Code + Happy Coder, authenticate |
| 5 | manual | LXC | Clone repos, sync config, set up MCP + 1Password |
| 6 | `scripts/setup-macbook.sh` | MacBook | SSH config, shell aliases, welcome dashboard |
| 7 | manual | — | iPhone access (Happy Coder app, Blink Shell) |
| 8 | `tests/verify-setup.sh` | Both | Verification (13 MacBook checks, 39 LXC checks) |

## Disaster Recovery

LXC 200 is **stateless** — all state lives in Git (GitHub) and shared config (Syncthing from MacBook). Recovery means re-creating the container and re-running the provisioning scripts. No backup restore needed.

```bash
# On the Proxmox host:
git clone https://github.com/bultot/claude-setup.git
bash claude-setup/scripts/disaster-recovery.sh
```

The script chains all provisioning phases automatically (~10-15 minutes), then prints manual steps for re-authentication (Tailscale, Claude Code, GitHub SSH key, Syncthing, 1Password).

## Project Structure

```
claude-setup/
├── README.md                  # This file — why and how
├── CLAUDE.md                  # Project context for Claude Code
├── ROADMAP.md                 # 8-phase migration plan
├── STATUS.md                  # Project health (powers /status dashboard)
├── LICENSE                    # MIT
├── scripts/
│   ├── disaster-recovery.sh   # Full rebuild from scratch (Proxmox host)
│   ├── setup-lxc.sh           # Phase 1: LXC creation (Proxmox host)
│   ├── provision.sh           # Phase 2: Base packages (LXC as root)
│   ├── configure-user.sh      # Phase 3: User + shell config (LXC as root)
│   ├── install-claude.sh      # Phase 4: Claude Code + Happy Coder (LXC)
│   └── setup-macbook.sh       # Phase 6: MacBook thin-client (MacBook)
├── config/
│   ├── ssh-config             # SSH hosts for 'cc' and 'cc-raw'
│   ├── zshrc-lxc.sh           # LXC .zshrc (CC_MACHINE=lxc, shared config)
│   ├── bashrc-additions.sh    # Legacy bash config (replaced by zsh)
│   └── happy-coder.service    # Systemd service for persistent Happy Coder
├── docs/
│   ├── quick-reference.md     # Daily cheat sheet
│   └── troubleshooting.md     # Common issues and fixes
└── tests/
    └── verify-setup.sh        # Automated verification (MacBook + LXC)
```

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
