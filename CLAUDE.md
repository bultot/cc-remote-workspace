# CC Remote Workspace

## Project Overview

This project sets up a persistent Claude Code environment on a Proxmox LXC container, accessible from any device (MacBook, iPhone, browser) via Happy Coder and SSH/tmux over Tailscale. The goal is to completely decouple Claude Code from the MacBook, making it an always-on service on the home server.

## Owner

- **Name**: Robin Bultot
- **Proxmox host**: Already running with existing LXC/VM infrastructure including Home Assistant, Docker services
- **Tailscale**: Already installed on MacBook and iPhone
- **Claude subscription**: Max plan (all Claude Code usage must go through Max, never API tokens)
- **Primary devices**: MacBook (Ghostty terminal), iPhone (Happy Coder + Blink Shell)
- **Knowledge vault**: Obsidian

## Architecture

```
Proxmox Host
└── LXC 200: claude-code (Ubuntu 24.04)
    ├── Claude Code (authenticated with Max subscription)
    ├── Happy Coder CLI (session relay to phone/mac)
    ├── tmux (session persistence, fallback access)
    ├── Tailscale (encrypted P2P mesh networking)
    ├── Git repos (cloned from GitHub)
    ├── MCP servers (API-based: GitHub, Salesforce, etc.)
    └── Node.js 22.x runtime

Access paths:
  iPhone  → Happy Coder app  → relay → VPS
  iPhone  → Blink Shell/Mosh → Tailscale → VPS
  MacBook → Happy Coder Mac  → relay → VPS
  MacBook → Ghostty SSH      → Tailscale → VPS
  Browser → Happy Coder web  → relay → VPS
```

## Tech Stack

- **Container**: Proxmox LXC (Ubuntu 24.04), 4 cores, 8GB RAM, 32GB disk
- **Runtime**: Node.js 22.x
- **Networking**: Tailscale (with Tailscale SSH enabled)
- **Session persistence**: tmux (with mobile-friendly keybindings)
- **Mobile bridge**: Happy Coder (npm: happy-coder)
- **Shell**: bash with auto-tmux wrappers
- **VPN tunnel device**: /dev/net/tun (required for Tailscale in LXC)

## Project Structure

```
cc-remote-workspace/
├── CLAUDE.md                 # This file — project context for Claude Code
├── ROADMAP.md                # Migration phases and task tracking
├── scripts/
│   ├── setup-lxc.sh          # Proxmox LXC creation script
│   ├── provision.sh          # Inside-LXC provisioning (packages, node, tailscale)
│   ├── configure-user.sh     # Create user, shell config, tmux, aliases
│   ├── install-claude.sh     # Claude Code + Happy Coder install and auth
│   ├── migrate-repos.sh      # Clone repos from GitHub to VPS
│   ├── migrate-config.sh     # Copy Claude settings, MCP configs, API keys
│   └── setup-macbook.sh      # MacBook thin-client SSH config and aliases
├── config/
│   ├── tmux.conf              # tmux configuration (mobile-friendly)
│   ├── bashrc-additions.sh    # Shell aliases and auto-tmux wrappers
│   ├── ssh-config             # MacBook ~/.ssh/config additions
│   └── mcp-servers.json       # MCP server configuration template
├── docs/
│   ├── quick-reference.md     # Cheat sheet for daily use
│   └── troubleshooting.md     # Common issues and fixes
└── tests/
    └── verify-setup.sh        # Post-install verification checklist script
```

## Coding Guidelines

- All scripts must be idempotent (safe to run multiple times)
- Scripts should check for prerequisites before executing
- Use `set -euo pipefail` in all bash scripts
- Include clear echo statements so Robin can follow progress
- Sensitive values (API keys, tokens) must never be hardcoded — use environment variables or prompt interactively
- Scripts that run ON the Proxmox host vs INSIDE the LXC must be clearly separated and labeled
- Test each phase independently before moving to the next
- Create Proxmox snapshots at key milestones

## Key Constraints

- LXC must have `nesting=1,keyctl=1` features enabled for Docker compatibility and Tailscale
- `/dev/net/tun` must be mounted for Tailscale to work inside LXC
- Claude Code must authenticate with Max subscription (not API key)
- Happy Coder wraps `claude` — use `happy` command instead of `claude` for sessions that need mobile access
- MCP servers that depend on macOS-local resources cannot be migrated — flag these during migration
- The LXC should auto-start on Proxmox boot (`onboot: 1`)
- tmux config must be mobile-friendly (mouse on, PageUp/F1 for copy mode, large scrollback)

## Workflow: Planning in Claude Chat → Executing in Claude Code

When Robin plans features or tasks in Claude Desktop/iOS chat:
1. Claude chat outputs a structured task spec in markdown
2. Robin saves it to `ROADMAP.md` or `tasks/` in the project repo
3. Claude Code reads it via this CLAUDE.md import and executes

@import ROADMAP.md

## Quick Commands Reference

```bash
# From MacBook
ssh cc                          # Jump into default tmux session on VPS
cc-sessions                     # List all running sessions
cc-project <name>               # Jump into specific project session

# On VPS
happy                           # Start Claude Code with Happy Coder relay
claude                          # Start Claude Code in tmux (auto-wrapped)
sessions                        # Show all tmux + happy sessions
tmux ls                         # List tmux sessions
tmux attach -t <name>           # Attach to specific session

# Maintenance
pct snapshot 200 <name>         # Snapshot LXC (run on Proxmox host)
pct rollback 200 <name>         # Rollback LXC (run on Proxmox host)
```
