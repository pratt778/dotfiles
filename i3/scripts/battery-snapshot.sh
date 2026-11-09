#!/usr/bin/env bash
# Crash-safety net for the i3 session (runs from i3-battery-snapshot.timer,
# every ~2 minutes). Quietly snapshots the session so that an ABRUPT power loss
# - battery hitting 0%, the charger being yanked, a power cut, a hard hang -
# can still be restored at the next boot (the snapshot leaves the `pending`
# restore flag set; answering "No" at the power menu clears it again).
#
# Save throttle (measured from the last successful auto-save):
#   battery <= 10% (discharging) -> save at most once per minute
#   running on battery power     -> save at most once every 5 minutes
#   plugged in (AC)              -> save at most once every 15 minutes
#   (a power cut while plugged in therefore loses at most 15 minutes of
#    window/tab arrangement - the apps' own saves cover document content)
#
# Skipped while a restore is running and during the first 90s of a boot so a
# half-restored desktop is never snapshotted.

set -uo pipefail

STATE="${I3_SESSION_STATE:-$HOME/.local/state/i3-session}"
TS_FILE="$STATE/last-autosave"
LOCK_DIR="$STATE/autosave.lock"
SAVE_SCRIPT="$HOME/.config/i3/scripts/session_lib.py"

[ -f "$STATE/pending.running" ] && exit 0            # restore in progress
uptime_s="$(cut -d. -f1 /proc/uptime 2>/dev/null || echo 0)"
[ "$uptime_s" -lt 90 ] && exit 0                     # still booting

# battery + AC state --------------------------------------------------------
BAT=""
for b in /sys/class/power_supply/BAT*; do
    [ -d "$b" ] && BAT="$b" && break
done
AC_ONLINE=1
for a in /sys/class/power_supply/AC*/online \
         /sys/class/power_supply/ADP*/online \
         /sys/class/power_supply/ACAD*/online; do
    [ -f "$a" ] && { AC_ONLINE="$(cat "$a" 2>/dev/null || echo 1)"; break; }
done

CAP=100
STATUS="Unknown"
if [ -n "$BAT" ]; then
    CAP="$(cat "$BAT/capacity" 2>/dev/null || echo 100)"
    STATUS="$(cat "$BAT/status" 2>/dev/null || echo Unknown)"
fi

low=0
if [ "$CAP" -le 10 ] && [ "$STATUS" != "Charging" ] && [ "$STATUS" != "Full" ]; then
    low=1
fi
on_battery=0
if [ "$AC_ONLINE" = "0" ] || [ "$STATUS" = "Discharging" ]; then
    on_battery=1
fi

# throttle ------------------------------------------------------------------
if [ "$low" -eq 1 ]; then
    interval=60
elif [ "$on_battery" -eq 1 ]; then
    interval=300
else
    interval=900
fi

now="$(date +%s)"
last=0
[ -f "$TS_FILE" ] && last="$(cat "$TS_FILE" 2>/dev/null || echo 0)"
case "$last" in ''|*[!0-9]*) last=0 ;; esac
[ $(( now - last )) -lt "$interval" ] && exit 0

# single-flight guard -------------------------------------------------------
mkdir -p "$STATE"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    exit 0    # another snapshot is already running
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null' EXIT

if python3 "$SAVE_SCRIPT" save --quiet; then
    date +%s > "$TS_FILE"
    if [ "$low" -eq 1 ] && command -v notify-send >/dev/null 2>&1; then
        notify-send -u critical -a "i3 Power Manager" \
            "Low battery ($CAP%) - session auto-saved" \
            "Your tabs and workspaces were snapshotted in case the battery dies." \
            2>/dev/null
    fi
fi
