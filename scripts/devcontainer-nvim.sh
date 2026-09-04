#!/usr/bin/env bash
# Open Neovim inside a running devcontainer, in its /workspaces folder.
#
# The devcontainer image carries nvim and stows this dotfiles repo (see the
# README section "devcontainer"), so the editor in there is the same one as on
# the host. devcontainer-lib.sh finds the container, the user and the folder;
# this file only says what to run in it.

set -uo pipefail

# readlink -f, so this still finds the library when the launcher is reached
# through a symlink in ~/.local/bin.
. "$(dirname -- "$(readlink -f -- "$0")")/devcontainer-lib.sh" || exit 1

dc_tool=nvim
dc_tool_hint='the devcontainer image has to install it -- see .devcontainer/Dockerfile'
dc_examples=(
    "$self README.md"
    "$self -d firstx-master/Kh.Core src/Foo.cs"
    "$self -- --headless +PlugStatus +qa"
)

dc_main "$@"
