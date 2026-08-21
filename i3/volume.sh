#!/usr/bin/env bash
#
# Volume control (+/-/mute) with an on-screen OSD toast via dunst.
# Usage: volume.sh up|down|mute

SINK="@DEFAULT_SINK@"
STEP=3

case "$1" in
  up)
    CURRENT=$(pactl get-sink-volume "$SINK" | grep -oP '\d+(?=%)' | head -1)
    if [ -n "$CURRENT" ] && [ "$CURRENT" -lt 100 ]; then
      pactl set-sink-volume "$SINK" "+${STEP}%"
    fi
    ;;
  down)
    pactl set-sink-volume "$SINK" "-${STEP}%"
    ;;
  mute)
    pactl set-sink-mute "$SINK" toggle
    ;;
  *)
    exit 0
    ;;
esac

VOL=$(pactl get-sink-volume "$SINK" | grep -oP '\d+(?=%)' | head -1)
MUTED=$(pactl get-sink-mute "$SINK" | awk '{print tolower($2)}')

if [ "$MUTED" = "yes" ]; then
  TEXT="${VOL}% · MUTED"
else
  TEXT="${VOL}%"
fi

dunstify -a i3 -r 4231 -t 1200 "$TEXT" >/dev/null 2>&1 || true