#!/usr/bin/env bash
# Decide whether a non-nvim pane keeps C-j / C-k for itself.
#
# smart-splits.nvim's tmux side branches on @pane-is-vim, which nvim sets. fzf
# is the other app in this setup that owns C-j and C-k -- it moves through its
# result list with them -- and it runs in plain shell panes, where that option
# is never set. The old vim-tmux-navigator is_vim regex happened to list fzf
# alongside vim; this restores that, and only that. keys.conf reaches this
# script only for C-j and C-k in a pane that is not nvim, so the common path
# keeps costing no `ps` call.
#
# Behaviour otherwise matches @smart-splits_no_wrap: at the edge of the window
# the key does nothing rather than wrapping to the far side.
#
# Usage: pane-owns-key.sh <pane_tty> <pane_id> <key> <U|D>
set -uo pipefail

tty=${1:?}
pane=${2:?}
key=${3:?}
flag=${4:?}

if ps -o state= -o comm= -t "$tty" 2>/dev/null | grep -iqE '^[^TXZ ]+ +(\S+\/)?fzf$'; then
    exec tmux send-keys -t "$pane" "$key"
fi

case "$flag" in
    U) edge='#{pane_at_top}' ;;
    D) edge='#{pane_at_bottom}' ;;
    *) printf 'pane-owns-key.sh: unknown flag: %s\n' "$flag" >&2; exit 2 ;;
esac

[ "$(tmux display-message -p -t "$pane" "$edge")" = 1 ] && exit 0

exec tmux select-pane -t "$pane" "-$flag"
