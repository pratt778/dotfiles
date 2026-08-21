#!/usr/bin/env bash
#
# Brightness control (+/-) with an on-screen OSD toast via dunst.
# Usage: brightness.sh up|down

case "$1" in
  up)   brightnessctl set +5% ;;
  down) brightnessctl set 5%- ;;
esac

LEVEL=$(brightnessctl -m info | awk -F, '{print int($4)}')
dunstify -a i3 -r 4232 -t 1200 "Brightness: ${LEVEL}%" >/dev/null 2>&1 || true