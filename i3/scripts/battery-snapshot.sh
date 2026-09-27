#!/usr/bin/env bash
# Background snapshot daemon/hook:
# Checks battery percentage. If battery is discharging and <= 10%,
# it triggers a quiet session snapshot so that if the laptop dies abruptly,
# your exact workspaces and tabs will still be recovered upon booting back up!

set -uo pipefail

STATE="${I3_SESSION_STATE:-$HOME/.local/state/i3-session}"
SNAPSHOT_FLAG="$STATE/battery_snapshot_done"

# Find battery device
BAT_DIR=""
for bat in /sys/class/power_supply/BAT*; do
    if [ -d "$bat" ]; then
        BAT_DIR="$bat"
        break
    fi
done

if [ -z "$BAT_DIR" ]; then
    exit 0
fi

CAPACITY=$(cat "$BAT_DIR/capacity" 2>/dev/null || echo "100")
STATUS=$(cat "$BAT_DIR/status" 2>/dev/null || echo "Unknown")

# If charging or full, clear the snapshot flag so it can trigger next time it drains
if [ "$STATUS" = "Charging" ] || [ "$STATUS" = "Full" ] || [ "$CAPACITY" -gt 15 ]; then
    rm -f "$SNAPSHOT_FLAG"
    exit 0
fi

# If battery <= 10% and Discharging (or Not charging), take an automatic snapshot
if [ "$CAPACITY" -le 10 ]; then
    if [ ! -f "$SNAPSHOT_FLAG" ]; then
        python3 "$HOME/.config/i3/scripts/session_lib.py" save --quiet || true
        touch "$SNAPSHOT_FLAG"
        if command -v notify-send >/dev/null 2>&1; then
            notify-send -u critical -a "i3 Power Manager" \
                "Low Battery ($CAPACITY%) - Workspaces Saved" \
                "Your exact tabs and session were safely snapshotted in case the laptop dies."
        fi
    fi
fi
