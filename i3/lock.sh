#!/bin/bash
# Lock the screen.
# NOTE: was `betterlockscreen -l blur`, but betterlockscreen is not installed
# on this machine. i3lock is (and is what xss-lock already uses on suspend).
# If you install betterlockscreen and prefer the blur background, restore this
# line instead.
i3lock --nofork --ignore-empty-password
