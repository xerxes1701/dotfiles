#!/usr/bin/env bash
# Open fish in a devcontainer, in its /workspaces folder -- starting the
# container first if it is not up, or building one from the project's image if
# there is no container at all.
#
# A plain shell in the container, for the moment when neither nvim nor herdr
# is the point: a one-off build, a quick look at a log, a tool that only lives
# in the image. The devcontainer image stows this dotfiles repo (see the README
# section "devcontainer"), so the fish in there has the same config.fish, the
# same aliases and the same prompt as the one on the host. devcontainer-lib.sh
# finds the container, the user and the folder; this file only says what to
# run in it.

set -uo pipefail

# readlink -f, so this still finds the library when the launcher is reached
# through a symlink in ~/.local/bin.
. "$(dirname -- "$(readlink -f -- "$0")")/../lib/dotfiles/devcontainer-lib.sh" || exit 1

dc_tool=fish
dc_tool_hint='the devcontainer image has to install it -- see .devcontainer/Dockerfile'
dc_examples=(
    "$self"
    "$self --container firstx-master"
    "$self -d firstx-master/Kh.Core"
    "$self -- -c 'dotnet build'"
)

dc_main "$@"
