#!/usr/bin/env bash

rofi_command=(
    rofi
    -dmenu
    -no-config
    -no-custom
    -only-match
    -selected-row 5
    -kb-cancel "Control+g,Control+bracketleft"
    -kb-custom-1 "Escape"
    -me-select-entry ""
    -me-accept-entry "MousePrimary"
    -mesg "Power Menu"
    -theme "$HOME/.config/rofi/powermenu.rasi"
)

chosen="$(
    printf '%b' \
        'Shutdown\0icon\x1fsystem-shutdown\n' \
        'Reboot\0icon\x1fsystem-reboot\n' \
        'Lock\0icon\x1fsystem-lock-screen\n' \
        'Suspend\0icon\x1fsystem-suspend\n' \
        'Logout\0icon\x1fsystem-log-out\n' \
        'Cancel\0icon\x1fwindow-close\n' |
        "${rofi_command[@]}"
)"
rofi_status=$?

if [ "$rofi_status" -ne 0 ]; then
    exit 0
fi

case $chosen in
    ""|"Cancel")
        exit 0
        ;;
    "Shutdown")
        posix_power=shutdown
        ;;
    "Reboot")
        posix_power=reboot
        ;;
    "Lock")
        ~/.config/i3/lock.sh &
        exit 0
        ;;
    "Suspend")
        ~/.config/i3/lock.sh &
        sleep 0.5
        systemctl suspend
        exit 0
        ;;
    "Logout")
        loginctl terminate-user $USER
        exit 0
        ;;
    *)
        exit 0
        ;;
esac

# Shutdown/Reboot go through power-session.sh, which asks whether to save the
# exact session first. Its dialog defaults to "No" (Enter/Escape = plain
# shutdown), so the old immediate behaviour is one key press away.
exec "$HOME/.config/i3/scripts/power-session.sh" "$posix_power"
