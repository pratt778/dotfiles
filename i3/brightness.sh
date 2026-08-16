#!/usr/bin/env bash
# Brightness control via sysfs — no external tool required.
# Requires write access to /sys/class/backlight/*/brightness (see
# udev-backlight.rules). Usage:
#   brightness.sh get        # print current percent
#   brightness.sh set +5     # brightness up 5%
#   brightness.sh set -5     # brightness down 5%
set -euo pipefail

card="$(ls /sys/class/backlight 2>/dev/null | head -1)"
[ -n "$card" ] || { echo "no backlight device found" >&2; exit 1; }
dir="/sys/class/backlight/$card"
brightness_file="$dir/brightness"
max_file="$dir/max_brightness"

v=$(( $(cat "$brightness_file") ))
m=$(( $(cat "$max_file") ))
[ "$m" -le 0 ] && m=1

case "${1:-get}" in
  get)
    printf '%d\n' $(( v * 100 / m ))
    ;;
  set)
    delta="${2:?usage: $0 set +N | set -N}"
    sign=+
    case "$delta" in
      +*) d="${delta#+}" ;;
      -*) sign=- ; d="${delta#-}" ;;
      *)  d="$delta" ;;
    esac
    step=$(( m * d / 100 ))
    [ "$step" -lt 1 ] && step=1
    if [ "$sign" = - ]; then v=$(( v - step )); else v=$(( v + step )); fi
    [ "$v" -lt 1 ] && v=1
    [ "$v" -gt "$m" ] && v="$m"
    printf '%s' "$v" > "$brightness_file"
    ;;
  *)
    echo "usage: $0 get | set +N | set -N" >&2
    exit 2 ;;
esac