#!/usr/bin/env bash
#
# Clipboard history picker.
# greenclip keeps a history in the background; this script shows it in a rofi
# menu and, once you pick an entry, puts it back on your clipboard (and
# primary selection for X11 middle-click paste).

if ! command -v greenclip >/dev/null 2>&1; then
  dunstify -a i3 -r 4233 -t 2000 "Clipboard" "greenclip not installed" >/dev/null 2>&1
  exit 0
fi

sel=$(
  greenclip print 2>/dev/null \
    | grep -v '^[[:space:]]*$' \
    | rofi -dmenu -i -p "Clipboard" -lines 10 -width 45
)

if [ -n "$sel" ]; then
  printf '%s' "$sel" | xclip -selection clipboard 2>/dev/null
  printf '%s' "$sel" | xclip -selection primary 2>/dev/null
fi