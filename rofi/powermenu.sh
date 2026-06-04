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
        systemctl poweroff
        ;;
    "Reboot")
        systemctl reboot
        ;;
    "Lock")
        loginctl lock-session
        ;;
    "Suspend")
        systemctl suspend
        ;;
    "Logout")
        loginctl terminate-user $USER
        ;;
    *)
        exit 0
        ;;
esac
