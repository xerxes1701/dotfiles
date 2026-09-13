#!/usr/bin/env bash
# Do the steps that stowing cannot: install nvim's smart-splits.nvim checkout
# and link herdr's plugin against it.
#
# One checkout serves all three apps (see the README, section "navigation /
# how the pane grid crosses apps"). nvim owns it: it pins the commit and lazy
# clones it. tmux sources the tmux side straight out of that directory, so it
# needs nothing here. herdr instead registers it as a plugin, and until that
# link exists its ctrl+hjkl bindings name plugin actions that resolve to
# nothing -- the keys are silently dead, in herdr and in nvim panes alike.
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

# --- 2. herdr links its plugin against it ----------------------------------
# The manifest the link reads is herdr-plugin.toml in the checkout, and the
# four action ids it declares are what config.toml's ctrl+hjkl name.
printf '\n== herdr ==\n'
if ! command -v herdr >/dev/null 2>&1; then
    printf '  no herdr on PATH -- nvim and tmux are set up, herdr is not\n'
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

# --- 3. say whether it took ------------------------------------------------
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
