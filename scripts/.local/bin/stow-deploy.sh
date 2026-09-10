#!/usr/bin/env bash
# Deploy this repository's packages to ~ on this machine.
#
# The README's `stow */`, plus the packages that must not be folded into the
# working tree. stow-lib.sh does the work; this file only says which packages
# belong to this machine.
#
# Stowing is not the whole story for the navigation scheme: tmux and herdr both
# consume nvim's smart-splits.nvim checkout, so after a first deploy run the
# three steps under "navigation / after a fresh deploy" in the README.
# nav-parity.sh reports it if any of them is missing.

set -uo pipefail

# readlink -f, so this still finds the library when the launcher is reached
# through the symlink that stowing `scripts` puts in ~/.local/bin.
. "$(dirname -- "$(readlink -f -- "$0")")/../lib/dotfiles/stow-lib.sh" || exit 1

sd_where=host
# Nothing is replaced here: this is the machine the packages are written for.
sd_exclude=()
sd_extra=()
# Folded, a package's ~/.config/<name> is a symlink into this repository, and
# whatever the tool writes there shows up as a change to the working tree:
#   fish   fisher and `fish_config theme save` write into ~/.config/fish
#   herdr  its socket, its logs and session.json live in ~/.config/herdr
#   scripts ~/.local/lib does not exist on a fresh machine, and folded it would
#          become a link into this repository for anything else to write into
# nvim and nushell stay folded on purpose -- what they generate in there is
# either tracked (lazy-lock.json) or listed in .gitignore.
sd_unfolded=(fish herdr scripts)
sd_examples=(
    "$self"
    "$self -n"
    "$self nvim tmux"
    "$self -R nushell"
)

sd_main "$@"
