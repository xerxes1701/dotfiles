#!/usr/bin/env bash
# Open herdr inside a running devcontainer, in its /workspaces folder.
#
# herdr is a terminal workspace manager for AI coding agents, and it keeps a
# persistent server of its own. Started in here it would manage panes on the
# host; started in the container -- what this script does -- its session, its
# agents and its worktrees all live next to the code they work on, inside the
# sandbox the devcontainer sets up for them.
#
# devcontainer-lib.sh finds the container, the user and the folder; this file
# only says what to run in it.

set -uo pipefail

# readlink -f, so this still finds the library when the launcher is reached
# through a symlink in ~/.local/bin.
. "$(dirname -- "$(readlink -f -- "$0")")/devcontainer-lib.sh" || exit 1

dc_tool=herdr
dc_tool_hint='the devcontainer image has to install it -- see .devcontainer/Dockerfile'
dc_examples=(
    "$self"
    "$self --container firstx-master"
    "$self status"
    "$self -- --session firstx"
)

dc_main "$@"
