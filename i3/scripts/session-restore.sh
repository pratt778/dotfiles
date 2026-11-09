#!/usr/bin/env bash
# Rebuild a saved i3 session: recreate the workspaces, replay the tiling layout
# with i3 placeholders and relaunch every app where it was.
#
# Called at login by startup-session.sh, but it only acts when a session was
# saved on purpose (the "pending" flag). For a manual test:
#   ~/.config/i3/scripts/session-restore.sh --dry-run          # show the plan
#   ~/.config/i3/scripts/session-restore.sh --force            # restore now
#   ~/.config/i3/scripts/session_lib.py status                 # what is saved
set -uo pipefail

exec python3 "${HOME}/.config/i3/scripts/session_lib.py" restore "$@"
