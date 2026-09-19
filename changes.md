# Changes Between `main` and `mint_ssd`

This document summarizes the config differences on the `mint_ssd` branch
compared to `main`.

## Files Changed

- `README.md`
- `i3/config`
- `i3/startup-placement.sh`
- `kitty/kitty.conf`
- `nvim/**`
- `picom/picom.conf`
- `polybar/polybar`
- `polybar/config.ini`
- `starship/starship.toml`
- `zsh/.zshrc`

## What Changed

### `i3/config`

- Picom is launched with an explicit config file:
  - from `picom -b`
  - to `picom --config ~/.config/picom.conf -b`
- Wallpaper path was corrected:
  - from `~/.wallpaper.png`
  - to `~/prathamsharma/config_files/wallpapers/wallpaper.png`
- Kitty launcher was changed to the newer installed binary:
  - `Mod+Enter` now launches `~/.local/kitty.app/bin/kitty`
  - `Mod+b` now launches `~/.local/kitty.app/bin/kitty -e ranger`
- Added classic window cycling with `Alt+Tab` and `Alt+Shift+Tab`
  (`focus next` / `focus prev`).
- Workspaces can now also be switched with `Alt+1`..`Alt+0`, and windows moved
  to them with `Alt+Shift+1`..`Alt+Shift+0`, so the `Mod4+N` bindings are no
  longer the only option.
- Added quick workspace hops:
  - `Mod4+Tab` cycles back to the previous workspace (`workspace back_and_forth`)
  - `Mod4+grave` goes to the next workspace
  - `Mod4+Shift+grave` goes to the previous workspace

### `i3/startup-placement.sh`

- Obsidian is no longer launched at login; its
  `launch_on_ws 3 obsidian flatpak run md.obsidian.Obsidian &` call was removed.
- Firefox is still placed on workspace 1.
- The header comment was updated to record both facts, so the script's
  behaviour is documented where it lives.

### `kitty/kitty.conf`

- Removed unsupported old cursor animation lines from the older Kitty version.
- Added cursor settings for Kitty `0.47.4`:
  - `shell_integration no-cursor`
  - `cursor_shape beam`
  - `cursor_beam_thickness 4.5`
  - `cursor_blink_interval 0.5`
  - `cursor_stop_blinking_after 0`
  - `cursor_trail 1`
  - `cursor_trail_decay 0.08 0.25`
  - `cursor_trail_start_threshold 1`
  - `cursor_trail_color none`
- Cursor styling now stays after the theme include so the theme does not
  override it.

### `picom/picom.conf`

- Fade animation was disabled:
  - `fading = true` became `fading = false`
- Fade steps were effectively neutralized:
  - `fade-in-step = 0.03` became `1.0`
  - `fade-out-step = 0.03` became `1.0`

Result: windows should appear and disappear immediately instead of easing in
and out.

### `starship/starship.toml`

- New Starship config file added.
- Sets `scan_timeout = 100` so directory scanning can take longer before
  warning.
- Uses a compact prompt with directory, git, command duration, and prompt
  symbol sections.

### `zsh/.zshrc`

- Added `~/.local/kitty.app/bin` to `PATH` so `kitty` resolves to the newer
  installed version.
- Keeps `~/.npm-global/bin` in `PATH`.
- Exports `STARSHIP_CONFIG` to point at the repo's Starship config.
- Runs `fastfetch` once for interactive Kitty shells.
- Keeps zsh autosuggestions and syntax highlighting sourced directly.
- Adds `~/flutter/bin` and `~/zero/bin` to `PATH` for the DartNative (`dn`)
  toolchain.

### `README.md`

- Added a branch README describing the config changes and reload steps.

### `polybar/polybar`

- Added as a symlink to the local Polybar directory.
- This looks environment-specific and may not be portable across machines.

### `polybar/config.ini`

- Made the bar smaller and tighter:
  - `height` `20pt` became `18pt`
  - `dpi` `150` became `120`
  - `line-size` `2pt` became `1pt`
  - `font-0` `FiraCode Nerd Font:size=9;2` became `:size=10;1`
  - workspace label padding `2` became `1`
- Uses a darker palette with lighter foreground text.
- Replaces plain text module prefixes with Nerd Font icons.
- Tightens workspace, window-title, network, CPU, memory, volume, and clock
  labels for a more compact layout.

### `nvim/`

- Replaced the pristine `kickstart.nvim` copy with the config that is actually
  in use, and symlinked `~/.config/nvim` at it.
- The config used to be a separate clone of `arjablc/nvim_conf`; that `.git`
  directory was removed so this repo is the single source of truth.
- The upstream `lua/knot/` modules were renamed to `lua/prat/`, so personal
  modules are no longer filed under the upstream author's name.
- `lua/vs_config/` was added for the VS Code Neovim extension; `init.lua` loads
  it only when `vim.g.vscode` is set, otherwise it loads `prat.configs` and
  `prat.plugin`.
- Upstream-only `.github/` workflow and issue-template files were dropped.
- `.nvimlog` is now git-ignored since it is a runtime log.

## Operational Effect

- `~/.config/nvim` reads straight from this repo, so Neovim edits are tracked
  like the other configs instead of living in a second clone.
- Windows should no longer fade in/out through Picom.
- Kitty should use the newer binary and show cursor trails.
- Starship should stop warning as quickly when scanning large directories and
  use a simpler prompt.
- Kitty shells should print Fastfetch on startup.
- Polybar should feel denser and more polished while taking slightly less
  vertical space.
- `Alt+Tab` should cycle windows and `Alt+N` should switch workspaces, which is
  easier to reach than the `Mod4+N` equivalents.
- Login no longer opens Obsidian on workspace 3.
- Fonts and cursor sizing are tuned a bit more for the small screen setup.
