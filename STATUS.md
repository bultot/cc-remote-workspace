# CC Remote Workspace

**Status**: active
**Last Updated**: 2026-02-08
**Progress**: 62% (5/8 phases complete)

## Current Focus

Migrating Claude Code to a dedicated Proxmox LXC container (LXC 200) so it runs as an always-on service accessible from any device.

## Completed

- [x] Phase 1: LXC 200 created (Ubuntu 24.04, 4c/8GB/32GB, TUN device)
- [x] Phase 2: Node.js 22.22, Tailscale, tmux, git, gh CLI installed
- [x] Phase 3: Robin user, tmux config, auto-tmux wrappers, SSH key for GitHub
- [x] Phase 4: Claude Code 2.1.37 + Happy Coder authenticated with Max
- [x] Phase 5: 10 repos cloned, full Claude config synced, MCP servers with 1Password
- [x] SSH config (`ssh cc` / `ssh cc-raw`) added to MacBook
- [x] 1Password CC Shared Credentials vault with service account for LXC

## Pending

- [ ] Phase 6: Finish MacBook thin-client aliases and setup-macbook.sh script
- [ ] Phase 7: Configure iPhone access (Happy Coder pairing, Blink Shell)
- [ ] Phase 8: Verification script, troubleshooting docs, 1-week burn-in
- [ ] Test MCP servers end-to-end on LXC (need `op signin` on LXC first)
- [ ] Authenticate Salesforce CLI on LXC (`sf auth`)

## Blockers

None — ready to continue with Phase 6.

## Notes

- Proxmox snapshots exist at each phase for easy rollback
- BambooHR MCP not migrated (custom build from work repo, not on GitHub)
- `midi-controller-pbf4` repo not cloned (no git remote)
- Thin pool space warning on Proxmox — consider snapshot rotation
