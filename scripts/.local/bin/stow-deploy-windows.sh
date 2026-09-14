#!/usr/bin/env bash
# Deploy this repository's packages to ~ on a Windows machine, from Git Bash.
#
# The same set as stow-deploy.sh with one package swapped: herdr/ is written
# for a linux host -- fish as the pane shell, bash scripts behind the custom
# commands -- and herdr on Windows can run neither. .herdr-windows takes its
# place, the way .herdr-devcontainer does in a container. See the README,
# section "windows".
#
# Symlinks are the other thing Windows changes. msys copies files instead of
# linking them unless MSYS=winsymlinks:nativestrict is set, and creating a
# native link needs Developer Mode or an elevated shell; stow-lib.sh sets the
# variable and probes for the privilege before stow touches anything, because
# stow's own failure modes for both are a silent copy or a half-done run.
#
# Stowing is not the whole story for the navigation scheme: herdr consumes
# nvim's smart-splits.nvim checkout, which only nvim can create -- on Windows
# under %LOCALAPPDATA%\nvim-data, not ~/.local/share, so nav-setup.sh does not
# apply here; link it by hand:
#   herdr plugin link "$LOCALAPPDATA/nvim-data/lazy/smart-splits.nvim"

set -uo pipefail

# readlink -f, so this still finds the library when the launcher is reached
# through the symlink that stowing `scripts` puts in ~/.local/bin.
. "$(dirname -- "$(readlink -f -- "$0")")/../lib/dotfiles/stow-lib.sh" || exit 1

sd_where=windows
#   herdr  the linux host config. .herdr-windows takes its place: pwsh as the
#          pane shell and the .ps1 twins of the scripts behind the custom
#          commands, with the same keys.
sd_exclude=(herdr)
# Hidden, so `stow */` on a linux host never matches it -- two visible
# packages providing .config/herdr/config.toml would abort every deploy.
sd_extra=(.herdr-windows)
# See stow-deploy.sh for what folding costs. herdr's package is not deployed
# here, but its replacement needs the same treatment: herdr writes its socket,
# logs and session.json into ~/.config/herdr.
sd_unfolded=(claude fish .herdr-windows scripts ssh)
sd_examples=(
    "$self"
    "$self -n"
    "$self --list"
    "$self nvim wezterm"
)

sd_main "$@"
