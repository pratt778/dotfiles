#!/usr/bin/env bash
# Place the once-per-login startup apps on their dedicated workspaces.
#   Firefox → workspace 1 (see launch calls at the bottom).
#   Obsidian is intentionally NOT launched here anymore.
#
# Why a script instead of i3 `assign` rules? An `assign` rule fires for every
# window of that class, so manually launching the app (rofi / Mod+d / ...)
# would also be yanked onto its dedicated workspace. Here each app is placed
# only while this script runs (i.e. only at login); any later launch follows
# whatever workspace you are currently on.
#
# kitty is NOT handled here: it uses an assign rule matched to a distinct X11
# class (--class StartupKitty, see i3 config), which works cleanly for it.

set -euo pipefail

# Launch an app and, once its first window appears, move it to a workspace.
launch_on_ws () {
    local ws="$1"
    local cls="$2"
    shift 2

    "$@" &
    local pid=$!

    # Poll the i3 tree until a window with this WM_CLASS shows up, then move it.
    # No class override needed — manual launches (outside login) are untouched.
    for _ in $(seq 1 60); do
        if i3-msg -t get_tree | grep -q "\"class\": *\"$cls\""; then
            i3-msg "[class=\"$cls\"] move container to workspace number \"$ws\"" >/dev/null
            return 0
        fi
        sleep 0.5
    done

    # App never mapped in time: reap it quietly and leave it where it opened.
    wait "$pid" 2>/dev/null || true
    return 0
}

# Firefox → workspace 1 (fresh instance so this never hijacks an existing one).
launch_on_ws 1 firefox firefox --new-instance &

wait || true