#!/usr/bin/env bash
# Resize the boundary of the focused herdr pane, or let nvim resize its split.
#
# The herdr side of layer 0 of the unified navigation scheme. smart-splits.nvim
# ships a herdr plugin for C-hjkl (its own scripts/herdr-navigate.sh) but no
# resize actions, and a plain herdr binding on ctrl+arrows would take the keys
# before nvim ever saw them -- so an nvim pane could no longer resize its own
# splits. This makes the same decision the navigation plugin makes:
#
#   nvim in the focused pane -> forward the key and let smart-splits.nvim
#       decide, which resizes the split when there is one in that direction
#   anything else            -> resize the herdr pane directly
#
# tmux gets this for free: the smart-splits.nvim tmux plugin binds the same
# keys through its @pane-is-vim test. See tmux/.config/tmux/navigation.conf.
#
# `--mux-only` skips the nvim check and always resizes the herdr pane. That is
# for nvim itself: when its window has no split to resize in that direction,
# smart-splits.nvim hands the resize to the multiplexer -- and it passes its
# cell count straight through, while `herdr pane resize --amount` is a
# *fraction of the split*, so 3 reads as 300% and slams the split to its
# minimum. nvim calls this instead (see lua/plugins/smart-splits.lua), so the
# conversion below is the one place that knows herdr's unit.
#
# Bound from both herdr configs as a `type = "shell"` custom command, which
# herdr runs through /bin/sh -lc and gives HERDR_ACTIVE_PANE_ID and
# HERDR_BIN_PATH. Requires jq, as the navigation plugin does.
#
# Usage: herdr-resize-pane.sh <left|down|up|right> [--mux-only]
set -uo pipefail

dir=${1:?usage: herdr-resize-pane.sh <left|down|up|right> [--mux-only]}
mode=${2:-}
herdr=${HERDR_BIN_PATH:-herdr}
pane=${HERDR_ACTIVE_PANE_ID:-${HERDR_PANE_ID:-}}

# 3 cells, the same step smart-splits.nvim takes in nvim (default_amount) and
# in tmux (@smart-splits_resize_step_size).
cells=3

case "$dir" in
    left)  key=ctrl+left;  axis=width ;;
    right) key=ctrl+right; axis=width ;;
    up)    key=ctrl+up;    axis=height ;;
    down)  key=ctrl+down;  axis=height ;;
    *) printf 'herdr-resize-pane.sh: unknown direction: %s\n' "$dir" >&2; exit 2 ;;
esac

command -v jq >/dev/null 2>&1 || exit 0
[ -n "$pane" ] || exit 0

if [ "$mode" != "--mux-only" ]; then
    # Kept character for character in step with smart-splits.nvim's own
    # herdr-navigate.sh, so navigation and resizing never disagree about which
    # panes belong to the editor.
    vim_re='^g?(view|l?n?vim?x?)(diff)?$'
    passthrough_re=${SMART_SPLITS_HERDR_PASSTHROUGH_RE:-}
    if "$herdr" pane process-info --pane "$pane" 2>/dev/null \
        | jq -e --arg vim "$vim_re" --arg pass "$passthrough_re" \
            '.result.process_info.foreground_processes[]?.name
             | ascii_downcase
             | select(test($vim) or ($pass != "" and (try test($pass) catch false)))' >/dev/null 2>&1; then
        exec "$herdr" pane send-keys "$pane" "$key"
    fi
fi

# The fraction that moves the boundary by `cells`. The denominator is the pane
# area of the tab, which is what the split's ratio is a fraction of -- not the
# pane's own size, and not the terminal's.
amount=$("$herdr" pane edges --pane "$pane" 2>/dev/null \
    | jq -r --argjson cells "$cells" --arg axis "$axis" \
        'if (.result.edges.layout.area[$axis] // 0) > 0
         then ($cells / .result.edges.layout.area[$axis])
         else empty end')
[ -n "$amount" ] || exit 0

exec "$herdr" pane resize --direction "$dir" --amount "$amount" --pane "$pane"
