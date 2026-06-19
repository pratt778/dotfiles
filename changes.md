# Changes Between `main` and `mint_ssd`

This document summarizes the config differences on the `mint_ssd` branch
compared to `main`.

## Files Changed

- `README.md`
- `i3/config`
- `kitty/kitty.conf`
- `picom/picom.conf`
- `polybar/polybar`
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

### `README.md`

- Added a branch README describing the config changes and reload steps.

### `polybar/polybar`

- Added as a symlink to the local Polybar directory.
- This looks environment-specific and may not be portable across machines.

### `polybar/config.ini`

- Keeps the same bar height, but switches to a tighter visual style.
- Uses a darker palette with lighter foreground text.
- Replaces plain text module prefixes with Nerd Font icons.
- Tightens workspace, window-title, network, CPU, memory, volume, and clock
  labels for a more compact layout.

## Operational Effect

- Windows should no longer fade in/out through Picom.
- Kitty should use the newer binary and show cursor trails.
- Starship should stop warning as quickly when scanning large directories and
  use a simpler prompt.
- Kitty shells should print Fastfetch on startup.
- Polybar should feel denser and more polished without taking more vertical
  space.
- Fonts and cursor sizing are tuned a bit more for the small screen setup.
