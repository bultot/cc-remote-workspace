# Claude Setup

**Status**: active
**Last Updated**: 2026-02-09
**Progress**: 98% (disaster recovery script added, burn-in pending)

## Current Focus

Phase 8 complete: verification script passes (MacBook 13/13, LXC 39/39), troubleshooting docs written, Happy Coder persistent service deployed and running. Ready for 1-week burn-in.

## Completed

- [x] Phase 1: LXC 200 created (Ubuntu 24.04, 4c/8GB/32GB, TUN device)
- [x] Phase 2: Node.js 22.22, Tailscale, Zellij, git, gh CLI installed
- [x] Phase 3: Robin user, Zellij config, auto-Zellij wrappers, SSH key for GitHub
- [x] Phase 4: Claude Code 2.1.37 + Happy Coder authenticated with Max
- [x] Phase 5: 10 repos cloned, full Claude config synced, MCP servers with 1Password
- [x] Phase 6: MacBook thin-client setup (SSH config, aliases, welcome banner, setup-macbook.sh)
- [x] Phase 7: iPhone access documented (quick-reference.md, Mosh verified, Happy Coder/Blink Shell instructions)
- [x] 1Password CC Shared Credentials vault with service account for LXC
- [x] Syncthing real-time config sync (CLAUDE.md, commands/, hooks/) between MacBook and LXC
- [x] Zellij replaces tmux for session persistence (OSC 52 clipboard, layouts for Claude/Happy)
- [x] All tmux references cleaned from project (Zellij everywhere)
- [x] VPS welcome message: same styled header as MacBook + contextual shortcuts
- [x] Dashboard "suggested" section: shows progress, reason, focus, and pending items
- [x] Happy Coder systemd service for persistent phone/web relay
- [x] Shell harmonization: shared zshrc, Starship prompt with CC_MACHINE identity
- [x] Rich welcome dashboard (cc-dashboard with welcome/full/compact modes, ANSI cache)
- [x] Shared scripts: cc-cache-refresh for pre-rendered project status + usage stats
- [x] Disaster recovery script (scripts/disaster-recovery.sh) — full LXC 200 rebuild from scratch

## Pending

- [ ] 1-week burn-in: use VPS exclusively
- [ ] Pair Happy Coder on iPhone (scan QR from `screen -r happy-relay`)
- [x] Install zsh + Starship + eza on LXC (matching MacBook shell experience)
- [ ] Test MCP servers end-to-end on LXC (need `op signin` on LXC first)
- [ ] Authenticate Salesforce CLI on LXC (`sf auth`)

## Blockers

None — ready for burn-in.

## Notes

- Proxmox snapshots exist at each phase for easy rollback
- BambooHR MCP not migrated (custom build from work repo, not on GitHub)
- `midi-controller-pbf4` repo not cloned (no git remote)
- Thin pool space warning on Proxmox — consider snapshot rotation
- Claude config sync uses symlinks (~/.claude/{CLAUDE.md,commands,hooks} → ~/.claude-shared/) with Syncthing
- Starship config also symlinked: ~/.config/starship.toml → ~/.claude-shared/starship.toml
- Dashboard cache at ~/.cache/cc-dashboard/ — auto-refreshes when stale (>30 min)
- career-os project filtered from dashboard when on Backbase WiFi
