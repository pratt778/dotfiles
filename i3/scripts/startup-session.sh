#!/usr/bin/env bash
# Login dispatcher for the desktop startup apps.
#
#   saved session waiting -> rebuild it (session-restore.sh) and skip the
#                            default startup apps, so nothing is launched twice
#   nothing saved         -> the usual startup kitty + startup-placement.sh
#
# i3 config runs this once per login (see the exec lines in ~/.config/i3/config).
set -uo pipefail

STATE="${I3_SESSION_STATE:-$HOME/.local/state/i3-session}"

if [ -e "$STATE/pending" ]; then
    exec "$HOME/.config/i3/scripts/session-restore.sh"
fi

# Default startup: kitty pinned to workspace 2 by the i3 assign rule, then
# Firefox on workspace 1 (login only, see startup-placement.sh).
"$HOME/.local/kitty.app/bin/kitty" --class StartupKitty &
exec "$HOME/.config/i3/startup-placement.sh"
