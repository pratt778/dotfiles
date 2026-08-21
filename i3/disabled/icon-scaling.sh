#!/bin/bash
# Force icon scaling for common tray components
export XCURSOR_SIZE=24
export GTK_ICON_SIZE=24
export PANEL_ICON_SIZE=24

# Restart common tray applets with scaling
for app in nm-applet blueman-applet volumeicon; do
    killall $app 2>/dev/null
    sleep 1
    $app &
done
