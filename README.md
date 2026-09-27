# Mint SSD Dotfiles

This branch contains desktop configuration changes for the Linux Mint SSD setup.
The focus is faster window behavior, a working wallpaper path, Kitty cursor
trail support, Fastfetch startup output, and Starship timeout tuning.

## What Changed From `main`

### i3

- Starts Picom with the explicit config file at `~/.config/picom.conf`.
- Sets the wallpaper from `~/prathamsharma/config_files/wallpapers/wallpaper.png`.
- Launches the newer Kitty binary from `~/.local/kitty.app/bin/kitty`.
- Uses the newer Kitty binary for the Ranger shortcut.
- Startup apps moved behind `i3/scripts/startup-session.sh`, a one-shot login
  dispatcher: it replays a saved session when one is pending, otherwise it
  starts the usual Kitty + Firefox/`startup-placement.sh` pair. `Mod4+p` became
  the power menu (Shutdown/Reboot now go through `i3/scripts/power-session.sh`).

### Session save & restore

- `Mod4+p` → **Shutdown** or **Reboot** now asks:

  ```text
  Save this session before shutting down?

  Yes — save now, restore automatically at the next login
  No  — shut down normally, nothing is saved (default)
  ```

  The dialog defaults to **No**: Enter or Escape shuts down exactly like before.
- Answering **Yes** writes `~/.local/state/i3-session/`:
  - `session.json` — workspaces, windows, focus and one launch recipe per app,
  - `layouts/ws-*.json` — `i3-save-tree` dumps with `class`/`instance` swallow
    criteria, so splits, tabs and stacking come back,
  - `kitty/kitty-win-*.session` — a kitty session file per terminal window
    (tabs, splits, working directory and, when safe, the running program),
  - `firefox/<profile>/` — the Firefox session store (exact tabs and windows),
  - `chromium/<browser>_<profile>/` — the `Sessions` folder for Brave/Edge/
    Chromium plus their `--restore-last-session` launch recipe,
  - `pending` — the flag that makes the next login restore the session.
- Answering **No** clears that flag, so a stale save can never surprise a boot.
- At the next login `startup-session.sh` focuses each saved workspace, appends
  its layout (i3 plants placeholder windows), relaunches the apps so i3 swallows
  them into those placeholders, moves any window that landed on the wrong
  workspace, removes placeholders whose app never came back, and finally focuses
  the workspace/window that was focused when the session was saved.
- VS Code windows are relaunched with the project folder they had open (read
  from `~/.config/Code/User/globalStorage/storage.json`); Thunar windows reopen
  in the same directory; anything else falls back to its `.desktop` `Exec` line.

Helpers:

```sh
~/.config/i3/scripts/session_lib.py status          # what is saved + flag state
~/.config/i3/scripts/session-save.sh --dry-run      # show what would be saved
~/.config/i3/scripts/session-restore.sh --dry-run    # show the restore plan
~/.config/i3/scripts/session-restore.sh --force      # restore right now
~/.config/i3/scripts/session_lib.py clear            # drop the pending flag
~/.config/i3/scripts/session_lib.py clear --purge    # delete the saved session
```

Logs land in `~/.local/state/i3-session/logs/{save,restore}.log`.

### Kitty

- Replaced unsupported old cursor settings with Kitty `0.47.4` cursor settings.
- Uses a thicker beam cursor.
- Enables cursor trail animation:
  - `cursor_trail`
  - `cursor_trail_decay`
  - `cursor_trail_start_threshold`
  - `cursor_trail_color`
- Adds a local-only remote control socket so session save/restore can replay the
  exact tabs, splits and working directories of every Kitty window:

  ```conf
  allow_remote_control socket-only
  listen_on unix:@kitty-session-restore
  ```

  Remove those two lines to opt out: Kitty windows are then restored with their
  working directory only, and the session scripts skip the socket silently.

### Picom

- Disables fade animations so apps open and close immediately instead of easing in/out.

### Starship

- Adds `starship/starship.toml`.
- Sets `scan_timeout = 100` to avoid directory scan timeout warnings in large or slow directories.

### Zsh

- Adds the new Kitty binary path before system paths.
- Exports `STARSHIP_CONFIG` so Starship uses this repo's config.
- Runs Fastfetch once when opening an interactive Kitty shell.
- Keeps zsh autosuggestions and syntax highlighting sourced directly.

### Polybar

- `polybar/polybar` exists on this branch as a symlink to the local Polybar config directory.
- This looks environment-specific and may not be portable to other machines.

### Neovim

- `nvim/` is now the single source of truth for the Neovim config and is
  symlinked to `~/.config/nvim`.
- Replaces the old pristine `kickstart.nvim` copy that used to live here.
- The previous clone of `arjablc/nvim_conf` is no longer used and its `.git`
  directory was removed, so the config is versioned by this repo instead.
- Personal modules live under `lua/prat/` (the upstream `knot` modules were
  renamed to `prat`) and `lua/vs_config/` for the VS Code Neovim extension.
- `init.lua` loads `vs_config` when running inside VS Code, otherwise it loads
  `prat.configs` and `prat.plugin`.
- Upstream-only `.github/` workflow and issue-template files were dropped, and
  the runtime `.nvimlog` is ignored.

## Apply Changes

Reload i3:

```sh
i3-msg reload
```

Restart Picom:

```sh
pkill picom
picom --config ~/.config/picom.conf -b
```

Apply wallpaper:

```sh
feh --bg-fill ~/prathamsharma/config_files/wallpapers/wallpaper.png
```

Open a new Kitty window with `Mod+Enter`, then verify:

```sh
kitty --version
```

Expected version:

```text
kitty 0.47.4
```

Reload Kitty config inside Kitty:

```text
Ctrl+Shift+R
```

Verify Neovim loads the symlinked config:

```sh
nvim --headless -c 'lua print(vim.fn.stdpath("config"))' -c 'qall'
```

Expected output:

```text
/home/pratham/.config/nvim
```

### Session save & restore

The power menu change needs no reload — `Mod4+p` re-reads `rofi/powermenu.sh`
every time it runs. The new login startup takes effect on the next login
(`i3-msg reload` only re-runs `exec_always` lines).

Check that the plumbing works without shutting down:

```sh
python3 ~/.config/i3/scripts/session_lib.py save --dry-run     # what gets saved
python3 ~/.config/i3/scripts/session_lib.py status             # saved session + flag
python3 ~/.config/i3/scripts/session_lib.py restore --dry-run  # the restore plan
POWER_SESSION_ANSWER=no POWER_SESSION_DRY_RUN=1 \
    ~/.config/i3/scripts/power-session.sh shutdown             # dialog bypassed
```

After a real `Mod4+p` → Shutdown → **Yes** the flag file
`~/.local/state/i3-session/pending` exists; if it is ever left behind (for
example you answered Yes but did not shut down), clear it with
`~/.config/i3/scripts/session_lib.py clear` so the next boot starts clean.

