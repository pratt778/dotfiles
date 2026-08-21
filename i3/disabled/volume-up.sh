#!/bin/bash
current=$(pactl get-sink-volume @DEFAULT_SINK@ | grep -oP '\d+(?=%)' | head -1)
if [ "$current" -lt 153 ]; then
    pactl set-sink-volume @DEFAULT_SINK@ +3%
fi
killall -SIGUSR1 i3status
