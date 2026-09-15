#!/usr/bin/env bash
# Do the steps that stowing cannot: install nvim's smart-splits.nvim checkout,
# link herdr's plugin against it, and fetch zellij's navigator plugin.
#
# One checkout serves nvim, tmux and herdr (see the README, section "navigation
# / how the pane grid crosses apps"). nvim owns it: it pins the commit and lazy
# clones it. tmux sources the tmux side straight out of that directory, so it
# needs nothing here. herdr instead registers it as a plugin, and until that
# link exists its ctrl+hjkl bindings name plugin actions that resolve to
# nothing -- the keys are silently dead, in herdr and in nvim panes alike.
#
# zellij is the fourth app and the one exception: that checkout has no back-end
# for it, so its layer 0 comes from a separate wasm plugin, pinned below.
#
# This is the README's "after a fresh deploy" list as a script, and the order
# is the reason it is one: the link needs a directory that only nvim creates.
# It is idempotent, so it is also the thing to run after a `git pull` that
# moved the pinned commit.
#
# The server restart is not done by default. herdr picks up a new plugin on
# `server reload-config`, but a changed prefix or passthrough regex needs the
# server to go away and be relaunched from a fresh shell -- and that closes
# every pane in the running session. Pass --restart-server when that is what
# you want; on a fresh deploy there is no session to lose.
#
# nav-parity.sh reports what this fixes, and reports it again afterwards.
#
# Usage: nav-setup.sh [--restart-server]
set -uo pipefail

restart_server=no
case ${1:-} in
    "") ;;
    --restart-server) restart_server=yes ;;
    *) printf 'nav-setup.sh: usage: %s [--restart-server]\n' "${0##*/}" >&2; exit 2 ;;
esac

# readlink -f, so this still finds the repository when the script is reached
# through the symlink that stowing `scripts` puts in ~/.local/bin. This file
# lives in scripts/.local/bin, three levels below the repository.
root=$(cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")/../../.." && pwd) \
    || exit 1

checkout=$HOME/.local/share/nvim/lazy/smart-splits.nvim
spec=$root/nvim/.config/nvim/lua/plugins/smart-splits.lua

# zellij's half of layer 0, pinned here the way the spec pins the checkout.
# nav-parity.sh reads these three lines rather than repeating them.
vzn_version=0.2.1
vzn_sha256=c292313e4995a680203ac750298ba2a5294301bb03dff9fab53b8e12b8891e7d
vzn=$HOME/.local/share/zellij/plugins/vim-zellij-navigator.wasm

status=0

# --- 1. nvim installs the checkout -----------------------------------------
# `Lazy! install` is the bang form: it does not wait for the UI, which a
# headless nvim never draws. Missing plugins only -- it will not move a plugin
# that is already cloned, so the pinned-commit check below is separate.
printf '== nvim ==\n'
if ! command -v nvim >/dev/null 2>&1; then
    printf '  no nvim on PATH -- nothing else here can work\n'
    exit 1
fi
if [ -d "$checkout" ]; then
    printf '  checkout     already at %s\n' "$checkout"
else
    printf '  installing plugins (headless)...\n'
    nvim --headless "+Lazy! install" +qa >/dev/null 2>&1
fi

if [ ! -d "$checkout" ]; then
    printf '  checkout     MISSING at %s after install -- is the spec stowed?\n' "$checkout"
    printf '               spec expected at %s\n' "$spec"
    exit 1
fi

# The same comparison nav-parity.sh makes. Reported, not corrected: `Lazy!
# restore` would move every other plugin to lazy-lock.json as well, which is a
# bigger thing than this script is asking for.
pinned=$(grep -oP 'commit = "\K[0-9a-f]{40}' "$spec")
head=$(git -C "$checkout" rev-parse HEAD 2>/dev/null)
if [ "$head" = "$pinned" ]; then
    printf '  checkout     at the pinned commit %s\n' "${pinned:0:12}"
else
    printf '  checkout     at %s, spec pins %s -- run :Lazy restore\n' \
        "${head:0:12}" "${pinned:0:12}"
    status=1
fi

# --- 2. zellij gets the same layer 0, out of a plugin of its own -----------
# smart-splits.nvim ships no zellij back-end, because there is nothing in zellij
# for it to branch on: no pane-local option that nvim can set on load and clear
# on exit, the way tmux has @pane-is-vim. Its own README points at
# vim-zellij-navigator instead, which makes the same decision from the other
# side -- it asks zellij which client is focused and forwards the key when that
# pane is running an editor.
#
# A wasm blob from a release, not a checkout, so the pin is a version and a
# checksum instead of a commit. 0.2.1 is the version the pinned smart-splits.nvim
# documents; a newer one exists and is deliberately not taken, for the reason
# tmux does not clone its own copy of smart-splits -- two halves of one protocol
# move together or they drift.
printf '\n== zellij ==\n'
if ! command -v zellij >/dev/null 2>&1; then
    printf '  no zellij on PATH -- skipping its navigator plugin\n'
elif ! command -v curl >/dev/null 2>&1 || ! command -v sha256sum >/dev/null 2>&1; then
    printf '  navigator    needs curl and sha256sum to install %s\n' "$vzn_version"
    status=1
else
    have=
    [ -f "$vzn" ] && have=$(sha256sum "$vzn" | cut -d' ' -f1)
    if [ "$have" = "$vzn_sha256" ]; then
        printf '  navigator    already at the pinned %s\n' "$vzn_version"
    else
        # Any other content is replaced rather than reported: unlike the nvim
        # checkout, nothing here is a local edit worth keeping -- the file is
        # entirely determined by the two pins above.
        [ -n "$have" ] && printf '  navigator    not the pinned build, replacing it\n'
        printf '  downloading vim-zellij-navigator %s...\n' "$vzn_version"
        mkdir -p "$(dirname "$vzn")"
        tmp=$vzn.new
        url=https://github.com/hiasr/vim-zellij-navigator/releases/download/$vzn_version/vim-zellij-navigator.wasm
        if ! curl -fsSL -o "$tmp" "$url"; then
            printf '  navigator    DOWNLOAD FAILED from %s\n' "$url"
            rm -f "$tmp"
            status=1
        elif [ "$(sha256sum "$tmp" | cut -d' ' -f1)" != "$vzn_sha256" ]; then
            printf '  navigator    CHECKSUM MISMATCH -- not installing\n'
            printf '               expected %s\n' "$vzn_sha256"
            rm -f "$tmp"
            status=1
        else
            mv -f "$tmp" "$vzn"
            printf '  navigator    installed %s\n' "$vzn_version"
        fi
    fi
    # The config names the plugin through an alias, so a moved path is one edit
    # there and not eight. If the alias ever stops pointing here, the ctrl+hjkl
    # binds resolve to nothing and say so only by doing nothing.
    conf=$root/zellij/.config/zellij/config.kdl
    if ! grep -q 'vim-zellij-navigator location="file:~/.local/share/zellij/plugins/vim-zellij-navigator.wasm"' "$conf"; then
        printf '  alias        config.kdl does not point at %s\n' "$vzn"
        status=1
    fi

    # The one step this script cannot do for you. zellij grants a plugin its
    # permissions at a prompt, once per machine, and the prompt only appears
    # when something first messages the plugin -- which is the first ctrl+h.
    # Until it is answered the plugin loads and does nothing, which looks the
    # same from the keyboard as a binding that was never there.
    perms=${XDG_CACHE_HOME:-$HOME/.cache}/zellij/permissions.kdl
    if grep -qs 'vim-zellij-navigator' "$perms"; then
        printf '  permissions  granted\n'
    else
        printf '  permissions  not granted yet -- open zellij, press ctrl+z to\n'
        printf '               unlock, then ctrl+h, and answer y to the prompt\n'
    fi
fi

# --- 3. herdr links its plugin against it ----------------------------------
# The manifest the link reads is herdr-plugin.toml in the checkout, and the
# four action ids it declares are what config.toml's ctrl+hjkl name.
printf '\n== herdr ==\n'
if ! command -v herdr >/dev/null 2>&1; then
    printf '  no herdr on PATH -- the other three are set up, herdr is not\n'
    exit "$status"
fi
if [ ! -f "$checkout/herdr-plugin.toml" ]; then
    printf '  checkout has no herdr-plugin.toml -- upstream dropped it?\n'
    exit 1
fi

if herdr plugin list 2>/dev/null | grep -q 'smart-splits.nvim.*enabled'; then
    printf '  plugin       already linked and enabled\n'
else
    printf '  linking %s...\n' "$checkout"
    if ! out=$(herdr plugin link "$checkout" 2>&1); then
        printf '  link FAILED:\n'
        printf '%s\n' "$out" | sed 's/^/               /'
        exit 1
    fi
    printf '  plugin       linked\n'
fi

# The link is on disk either way; a running server only learns about it when
# it rereads its config.
if herdr status server >/dev/null 2>&1; then
    if [ "$restart_server" = yes ]; then
        printf '  stopping the server so it relaunches from a fresh shell...\n'
        herdr server stop >/dev/null 2>&1
    else
        herdr server reload-config >/dev/null 2>&1
        printf '  config       reloaded (pass --restart-server for a full restart,\n'
        printf '               which a changed prefix or passthrough regex needs)\n'
    fi
fi

# --- 4. say whether it took ------------------------------------------------
printf '\n== actions ==\n'
# `plugin action list` answers with the socket API's envelope, which carries an
# "id" of its own -- so the actions are counted through jq, not by grepping
# keys out of the JSON.
if command -v jq >/dev/null 2>&1; then
    n=$(herdr plugin action list 2>/dev/null | jq -r '.result.actions | length')
    [ -n "$n" ] || n=0
    if [ "$n" -ge 4 ]; then
        printf '  %s plugin actions registered\n' "$n"
    else
        printf '  %s actions registered -- ctrl+hjkl will still be dead\n' "$n"
        status=1
    fi
else
    printf '  no jq, cannot count the registered actions\n'
fi

printf '\nrun nav-parity.sh to check the whole scheme.\n'
exit "$status"
