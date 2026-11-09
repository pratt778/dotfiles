# GRUB Theme

Custom GRUB bootloader theme based on [vinceliuice/grub2-themes](https://github.com/vinceliuice/grub2-themes) (`stylish` variant), customized for a 1920x1200 display.

## What's customized

- **Background**: replaced with `night.jpg`, cropped/resized to 1920x1200 (no stretch distortion)
- **Fonts**: switched from Unifont 24pt to Terminus 16pt (menu items) / 14pt (countdown label) for sharper, less bulky text rendering
- **Info graphic position**: moved the keybind hint image (`info.png`, e.g. "c for cmd, enter for boot") from bottom-center to top-right

## Files

- `stylish/` — full theme folder as installed at `/boot/grub/themes/stylish/`, including fonts, icons, and the edited `theme.txt`
- `default-grub` — backup of `/etc/default/grub` with `GRUB_TIMEOUT`, `GRUB_GFXMODE`, and `GRUB_THEME` set correctly

## How to reapply on a fresh install

1. Clone the vinceliuice/grub2-themes repo and run the installer once to get base dependencies and folder structure handled:

   ```bash
   git clone https://github.com/vinceliuice/grub2-themes.git
   cd grub2-themes
   sudo ./install.sh -t stylish -c 1920x1200 -b
   ```

   Requires ImageMagick. If only ImageMagick 6.x is installed (`convert` works but `magick` doesn't), symlink it first:

   ```bash
   sudo ln -s $(which convert) /usr/local/bin/magick
   ```

2. Overwrite the installed theme with this customized version:

   ```bash
   sudo cp -r stylish/* /boot/grub/themes/stylish/
   ```

3. Restore the GRUB config:

   ```bash
   sudo cp default-grub /etc/default/grub
   ```

4. Regenerate and reboot:

   ```bash
   sudo update-grub
   sudo reboot
   ```

## Notes

- If using a different screen resolution, regenerate the background with:

  ```bash
  convert /path/to/image.jpg -resize WIDTHxHEIGHT^ -gravity center -extent WIDTHxHEIGHT background.jpg
  ```

- Font sizes and the info graphic position are set directly in `theme.txt` if further tweaking is needed.