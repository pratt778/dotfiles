#!/bin/bash
# Modern blurred lockscreen with clock, date and password indicator.
# Uses betterlockscreen with your custom wallpaper and midnight theme.

if command -v betterlockscreen >/dev/null 2>&1; then
    exec betterlockscreen -l blur
else
    exec i3lock --nofork --ignore-empty-password
fi
