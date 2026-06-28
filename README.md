# Dotfiles

Personal Linux configuration files. This branch is set up so the live config in
`~/.config` points into this repository with symlinks.

## How It Works

Most active configs are stored in this repo:

```txt
/home/prathams/prathamsharma/dotfiles
```

The matching live paths in `~/.config` are symlinks. For example:

```txt
~/.config/i3      -> /home/prathams/prathamsharma/dotfiles/i3
~/.config/kitty   -> /home/prathams/prathamsharma/dotfiles/kitty
~/.config/polybar -> /home/prathams/prathamsharma/dotfiles/polybar
```

Because of this, editing either path changes the same file.

## Edit Configs

Recommended workflow:

```sh
cd /home/prathams/prathamsharma/dotfiles
```

Common files:

```sh
nvim i3/config
nvim kitty/kitty.conf
nvim rofi/config.rasi
nvim fastfetch/config.jsonc
nvim polybar/config.ini
nvim picom/picom.conf
nvim starship/starship.toml
nvim tmux/tmux.conf
```

You can also edit through `~/.config`, for example:

```sh
nvim ~/.config/i3/config
```

That still edits the repo file because of the symlink.

## Save Changes To GitHub

After editing:

```sh
cd /home/prathams/prathamsharma/dotfiles
git status
git add .
git commit -m "Update configs"
git push
```

Use a more specific commit message when possible:

```sh
git commit -m "Update i3 keybindings"
```

## Reload Apps

Some configs need a reload before changes show up.

```sh
i3-msg reload
```

Kitty:

```txt
Ctrl+Shift+R
```

Polybar:

```sh
~/.config/polybar/launch.sh
```

Picom:

```sh
pkill picom
picom -b
```

Starship, fastfetch, and zsh changes usually need a new terminal session.

## Current Symlinks

Expected live links:

```txt
~/.config/kitty         -> dotfiles/kitty
~/.config/i3            -> dotfiles/i3
~/.config/fastfetch     -> dotfiles/fastfetch
~/.config/rofi          -> dotfiles/rofi
~/.config/nvim          -> dotfiles/nvim
~/.config/polybar       -> dotfiles/polybar
~/.config/picom.conf    -> dotfiles/picom/picom.conf
~/.config/starship.toml -> dotfiles/starship/starship.toml
```

Check them with:

```sh
ls -ld ~/.config/kitty ~/.config/i3 ~/.config/fastfetch ~/.config/rofi ~/.config/nvim ~/.config/polybar ~/.config/picom.conf ~/.config/starship.toml
```

## Backup

The pre-symlink config backup is stored at:

```txt
~/.config-backup-before-dotfiles
```

Use it only if you need to recover an old local copy.
