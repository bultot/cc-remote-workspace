# CC Remote Workspace — Quick Reference

> Daily commands, iPhone setup, and troubleshooting for your always-on Claude Code environment.

## MacBook Commands

| Command | Description |
|---------|-------------|
| `cc` | SSH into default Zellij session on LXC |
| `cc-sessions` | List all active Zellij sessions |
| `cc-project <name>` | Attach or create a named project session |
| `cc-claude [dir]` | Start Claude Code in a project directory |
| `cc-happy [dir]` | Start Happy Coder for phone relay |

## On the LXC (inside a session)

| Command | Description |
|---------|-------------|
| `claude` | Start Claude Code (auto-wraps in Zellij) |
| `happy` | Start Happy Coder (auto-wraps in Zellij) |
| `sessions` | List all Zellij and Happy Coder sessions |
| `zellij list-sessions` | List raw Zellij sessions |
| `zellij attach <name>` | Attach to a specific session |

## Zellij Shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl-p` | **Pane mode** — split, move, resize, close |
| `Ctrl-t` | **Tab mode** — new, rename, switch, close |
| `Ctrl-s` | **Scroll mode** — search, scroll through output |
| `Ctrl-o` | **Session manager** — switch between sessions |
| `Ctrl-q` | **Quit** — session stays alive for reattach |
| `Alt-d` | Detach from session |
| `Alt-n` | New pane |
| `Alt-1/2/3` | Switch to tab 1, 2, or 3 |

**Clipboard**: Select text with mouse → auto-copied to MacBook clipboard via OSC 52.

## Session Lifecycle

```
1. Start from MacBook       →  cc  (or cc-project myapi)
2. Close the lid            →  session stays alive on LXC
3. Reopen MacBook           →  cc  (same session, right where you left off)
4. Switch to iPhone         →  Happy Coder app
5. Back to MacBook          →  cc  (picks up again)
```

---

## iPhone Setup: Happy Coder

Happy Coder lets you interact with Claude Code sessions from your phone through a relay.

### Install

1. Install **Happy Coder** from the App Store:
   https://apps.apple.com/app/happy-coder/id6748571505

### Pair with LXC

2. From your MacBook, start Happy Coder on the LXC:
   ```bash
   cc-happy
   ```
   Or SSH in directly:
   ```bash
   ssh -t cc-raw "happy"
   ```

3. A QR code appears in the terminal. Scan it with the Happy Coder app on your iPhone.

4. Once paired, active sessions appear in the app. You can send messages to Claude Code and see responses.

### Daily Use

- Open Happy Coder on iPhone — active sessions show automatically
- Tap a session to interact with Claude Code
- Start new sessions from the app or from MacBook (`cc-happy <project>`)
- Sessions persist even when the app is closed

### Web Access (from any browser)

- Open https://app.happy.engineering
- Connect to your running `happy` session on the LXC

---

## Troubleshooting

### "Connection refused" or "Host not found"

```bash
# Check Tailscale is connected
tailscale status

# Verify LXC is reachable
ping claude-code
```

If Tailscale is down on iPhone, open the Tailscale app and reconnect.

### Session lost after reboot

Zellij sessions survive SSH disconnects but not LXC reboots. After a reboot:
```bash
cc                    # creates a new session automatically
```

To check if old sessions exist:
```bash
cc-sessions
```

### Claude Code authentication expired

SSH into the LXC and re-authenticate:
```bash
ssh cc-raw
claude login
```
Follow the browser link to re-authenticate with your Max subscription.

### Happy Coder not showing sessions

1. Make sure `happy` is running on the LXC:
   ```bash
   cc-happy
   ```
2. Re-pair if needed — the QR code refreshes each time you start `happy`
3. Check that your phone and LXC are both on Tailscale

### Syncthing config sync broken

If a Claude Code update overwrites symlinks:
```bash
~/.claude-shared/restore-symlinks.sh
```

### LXC not starting after Proxmox reboot

On the Proxmox host:
```bash
ssh beelink
pct status 200          # check status
pct start 200           # start if stopped
pct list                # verify onboot flag
```

---

## Architecture Reference

```
Proxmox Host (beelink)
└── LXC 200: claude-code (Ubuntu 24.04, 4c/8GB/32GB)
    ├── Claude Code (Max subscription)
    ├── Happy Coder (session relay for phone/web)
    ├── Zellij (session persistence + terminal multiplexer)
    ├── Tailscale (100.103.193.111)
    └── Syncthing (config sync with MacBook)

Access Paths:
  MacBook  → ssh cc (Ghostty)  → Tailscale → Zellij → Claude Code
  iPhone   → Happy Coder app   → relay     → Claude Code
  Browser  → app.happy.engineering → relay  → Claude Code
```

## Key Details

| Item | Value |
|------|-------|
| LXC ID | 200 |
| Tailscale IP | 100.103.193.111 |
| Tailscale hostname | claude-code |
| User | robin |
| SSH hosts | `cc` (Zellij), `cc-raw` (plain) |
| Terminal multiplexer | Zellij 0.43.1 |
| Syncthing folder | `claude-shared` |
| 1Password vault | CC Shared Credentials |
| Service account | claude-code-lxc |
