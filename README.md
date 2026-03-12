# xcv

Paste images into remote Claude Code and Codex over SSH from your local clipboard.

`xcv` keeps the transport simple:

- Claude Code: local clipboard daemon + SSH remote forward + remote `xclip` shim
- Codex: upload the clipboard image to the remote host, then paste the remote path

No X11 forwarding. No terminal-specific transport. Works over plain SSH.

## Quick Start

```bash
# Install
curl -fsSL https://raw.githubusercontent.com/tthuwng/xcv/main/scripts/install.sh | sh

# Setup (one command does everything)
xcv setup myserver
```

If `xcv` is not on your `PATH` yet, use the full path printed by the installer.

Done. `Ctrl+V` in remote Claude Code now pastes images from your local machine.

For Codex, you have two modes.

Manual:

```bash
xcv paste --copy
```

Then use your terminal's normal paste shortcut in Codex.

Automatic:

```bash
xcv watch start
```

After that, whenever your local clipboard changes to an image, `xcv` uploads it to every active `xcv` SSH session at one shared remote path under `/tmp` without changing your local clipboard. Pair this with a local hotkey that runs `xcv paste` and types the returned path into the terminal. That keeps macOS clipboard history clean and still makes remote image paste fast.

## What `xcv setup` does

- writes `~/.config/xcv/config`
- installs `~/.ssh/xcv.conf` and adds an `Include` line to `~/.ssh/config`
- starts the local clipboard daemon
- bootstraps the remote `xcv` helper and `xclip` shim on the target host
- stores the host you passed as the default fallback target
- remembers `xcv` SSH hosts and uses active sessions first for Codex auto-upload

After setup, plain interactive `ssh myserver` sessions automatically get the remote forward and on-demand remote bootstrap.

If a host disallows remote forwarding, SSH still works normally; only clipboard forwarding is unavailable on that host.

## Commands

```bash
xcv setup HOST
xcv paste --copy
xcv watch start
xcv doctor
```

`xcv paste` is an alias for `xcv codex-paste`.
`xcv watch start` is the opt-in Codex background staging mode across all active `xcv` SSH sessions.

## Hotkeys

The hotkey still runs locally because the clipboard lives on your laptop.

- macOS Hammerspoon example: `local/macos/hammerspoon-paste-image.lua.example`
- Linux X11 AutoKey example: `local/linux-x11/autokey-paste-image.py.example`

Both examples assume you already ran `xcv setup HOST`, so `xcv paste` or `xcv watch start` can use active `xcv` SSH sessions and fall back to the saved default host.

The macOS and Linux examples avoid rewriting your local clipboard. They run `xcv paste`, then type the remote path into the active terminal window.

## Requirements

Local machine:

- macOS: `pngpaste`
- Linux Wayland: `wl-clipboard`
- Linux X11: `xclip`

Remote host:

- `ssh`
- `curl`
- `bash`

## Notes

- `xcv setup HOST` is the main entrypoint.
- `xcv ssh HOST` still exists if you want an explicit wrapper instead of automatic SSH integration.
- `xcv watch start` is global to your local clipboard.
- `xcv watch start --copy` preserves the older behavior where the remote path is copied into your local clipboard.
- In automatic Codex mode, `xcv` syncs the latest image to all active `xcv` SSH sessions at one shared `/tmp/xcv-.../current.png` path and leaves your local clipboard unchanged by default.
- If there are no active `xcv` SSH sessions, Codex falls back to the saved default host from `xcv setup HOST`.
