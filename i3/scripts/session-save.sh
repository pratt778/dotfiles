#!/usr/bin/env bash
# Save the exact i3 session (workspaces, tiling layout, browser tabs, terminal
# tabs/cwd) so the next login can reopen it.
#
# Normally called by power-session.sh (Mod4+p -> Shutdown/Reboot -> Yes), but it
# is safe to run by hand:
#   ~/.config/i3/scripts/session-save.sh            # save now
#   ~/.config/i3/scripts/session-save.sh --dry-run  # show what would be saved
set -euo pipefail

exec python3 "${HOME}/.config/i3/scripts/session_lib.py" save "$@"
