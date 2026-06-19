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

### Kitty

- Replaced unsupported old cursor settings with Kitty `0.47.4` cursor settings.
- Uses a thicker beam cursor.
- Enables cursor trail animation:
  - `cursor_trail`
  - `cursor_trail_decay`
  - `cursor_trail_start_threshold`
  - `cursor_trail_color`

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
