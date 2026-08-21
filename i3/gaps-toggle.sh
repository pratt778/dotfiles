#!/usr/bin/env bash
#
# Toggle i3 window gaps between 0 (packed) and 6px (breathing room).
# Stored per-session in a small state file so i3-msg can flip it live.

STATE="$HOME/.config/i3/.gaps-state"
CUR=$(cat "$STATE" 2>/dev/null)

if [ "$CUR" = "6" ]; then
  G=0
else
  G=6
fi

i3-msg "gaps inner $G; gaps outer $G" >/dev/null 2>&1
printf '%s' "$G" > "$STATE"