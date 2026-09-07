#!/usr/bin/env bash
# Deploy this repository's packages inside a devcontainer.
#
# The image's build already does this (see DOTFILES_STOW_EXCLUDE in the
# project's .devcontainer/Dockerfile), so a container needs this script only
# after a `git pull` in ~/dotfiles brought a package it does not have yet.
#
# It deploys a different set than stow-deploy.sh: a container replaces two
# packages of its own, which is what keeps a herdr or a git config in there
# from being mistaken for the one on the host.

set -uo pipefail

# readlink -f, so this still finds the library when the launcher is reached
# through the symlink that stowing `scripts` puts in ~.
. "$(dirname -- "$(readlink -f -- "$0")")/stow-lib.sh" || exit 1

sd_where=devcontainer
#   git    the container runs `git config --global`, which would follow a
#          ~/.gitconfig symlink and dirty a tracked file. It writes a real
#          ~/.gitconfig that [include]s the packaged one instead.
#   herdr  the config of the host machine. .herdr-devcontainer takes its
#          place, so the two herdr instances do not look alike.
sd_exclude=(git herdr)
# Hidden, so neither `stow */` on the host nor the `for d in */` loop in the
# Dockerfile matches it. That is the point: only a container deploys it.
sd_extra=(.herdr-devcontainer)
# See stow-deploy.sh for what folding costs. herdr's package is not deployed
# here, but the container's replacement for it needs the same treatment.
sd_unfolded=(fish .herdr-devcontainer)
sd_examples=(
    "$self"
    "$self -n"
    "$self --list"
    "$self nvim"
)

sd_main "$@"
