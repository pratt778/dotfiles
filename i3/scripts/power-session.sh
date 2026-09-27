#!/usr/bin/env bash
# Ask whether to save the exact session, then perform the power action.
#
#   power-session.sh shutdown|reboot   ask, (maybe) save, then power off/reboot
#   power-session.sh save              save only, no power action
#   power-session.sh restore           restore the saved session right now
#
# Testing / scripting knobs:
#   POWER_SESSION_ANSWER=yes|no|cancel   skip the dialog and answer for it
#   POWER_SESSION_DRY_RUN=1              print the systemctl command instead of running
set -uo pipefail

ACTION="${1:-shutdown}"
DRY_RUN="${POWER_SESSION_DRY_RUN:-0}"
STATE="${I3_SESSION_STATE:-$HOME/.local/state/i3-session}"
SAVE_SCRIPT="$HOME/.config/i3/scripts/session-save.sh"
RESTORE_SCRIPT="$HOME/.config/i3/scripts/session-restore.sh"

# ------------------------------------------------------------------------- #
# direct actions (also handy for testing)
# ------------------------------------------------------------------------- #
case "$ACTION" in
    save)
        exec "$SAVE_SCRIPT"
        ;;
    restore)
        exec "$RESTORE_SCRIPT" --force
        ;;
esac

# Ask with a 3-button card prompt:
# [No, just proceed] [Yes, save session] [Cancel]
# - Default selected: "No, just proceed" (pressing Enter proceeds without saving)
# - Escape / clicking Cancel: aborts completely and returns to desktop!
ask_rofi() {
    local choice ret
    local theme="$HOME/.config/rofi/ask-save.rasi"
    if [ ! -f "$theme" ]; then
        theme="$HOME/.config/rofi/powermenu.rasi"
    fi
    choice="$(printf '%b' \
        'No, just proceed\0icon\x1fsystem-shutdown\n' \
        'Yes, save session\0icon\x1fdocument-save\n' \
        'Cancel\0icon\x1fwindow-close\n' |
        rofi -dmenu -i -no-custom -only-match \
            -selected-row 0 -show-icons \
            -p "Save session?" \
            -mesg "Reopen these exact tabs and workspaces next time?" \
            -theme "$theme" \
            2>/dev/null)"
    ret=$?

    # If Escape, Control+C, or window close was pressed (non-zero exit code):
    if [ "$ret" -ne 0 ]; then
        return 2  # Cancel / Abort
    fi

    case "$choice" in
        "Yes, save session"*)
            return 0  # Yes
            ;;
        "No, just proceed"*)
            return 1  # No
            ;;
        *)
            return 2  # Cancel
            ;;
    esac
}

ask_zenity() {
    local ans
    ans=$(zenity --list --radiolist --width=460 --height=260 \
        --title="Save session before shutting down?" \
        --text="Reopen these exact tabs and workspaces next time?" \
        --column="Select" --column="Action" \
        TRUE "No, just proceed" \
        FALSE "Yes, save session" 2>/dev/null)
    if [ $? -ne 0 ]; then
        return 2  # Cancel
    fi
    if [ "$ans" = "Yes, save session" ]; then
        return 0
    else
        return 1
    fi
}

notify() {
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -a "i3 session" "$@"
    fi
}

error_dialog() {
    if command -v zenity >/dev/null 2>&1; then
        zenity --error --width=460 --title="Session was not saved" --text="$1" >/dev/null 2>&1
    else
        notify "Session was not saved" "$1"
    fi
}

# ------------------------------------------------------------------------- #
# 1. ask the user
# ------------------------------------------------------------------------- #
answer="cancel"

if [ -n "${POWER_SESSION_ANSWER:-}" ]; then
    answer="$POWER_SESSION_ANSWER"
elif command -v rofi >/dev/null 2>&1; then
    ask_rofi
    code=$?
    if [ "$code" -eq 0 ]; then
        answer="yes"
    elif [ "$code" -eq 1 ]; then
        answer="no"
    else
        answer="cancel"
    fi
elif command -v zenity >/dev/null 2>&1; then
    ask_zenity
    code=$?
    if [ "$code" -eq 0 ]; then
        answer="yes"
    elif [ "$code" -eq 1 ]; then
        answer="no"
    else
        answer="cancel"
    fi
fi

# If Cancel or Escape was pressed: do NOT shutdown! Abort back to desktop safely.
if [ "$answer" = "cancel" ]; then
    if [ "$DRY_RUN" = "1" ]; then
        echo "DRY RUN: answer=cancel, aborted safely."
    fi
    exit 0
fi

# ------------------------------------------------------------------------- #
# 2. save (or make sure a stale save cannot surprise the next boot)
# ------------------------------------------------------------------------- #
if [ "$answer" = "yes" ]; then
    if "$SAVE_SCRIPT"; then
        summary="$(python3 - "$STATE/session.json" <<'PY' 2>/dev/null || true
import json, sys
try:
    data = json.load(open(sys.argv[1]))
except Exception:
    print("session saved")
else:
    print("session saved: %d window(s) on %d workspace(s) - reopening at next login"
          % (len(data.get("windows") or []), len(data.get("workspaces") or [])))
PY
)"
        notify "Session saved" "${summary:-session saved}"
        sleep 0.4
    else
        error_dialog "The session could not be saved, so nothing was restored later.
See $STATE/logs/save.log for details."
    fi
else
    rm -f "$STATE/pending"
fi

# ------------------------------------------------------------------------- #
# 3. power action
# ------------------------------------------------------------------------- #
case "$ACTION" in
    shutdown) power_cmd=(systemctl poweroff) ;;
    reboot)   power_cmd=(systemctl reboot) ;;
    logout)   power_cmd=(loginctl terminate-user "$USER") ;;
    *)
        echo "power-session.sh: unknown action '$ACTION' (shutdown|reboot|logout|save|restore)" >&2
        exit 2
        ;;
esac

if [ "$DRY_RUN" = "1" ]; then
    echo "DRY RUN: answer=$answer, would run: ${power_cmd[*]}"
    exit 0
fi

exec "${power_cmd[@]}"
