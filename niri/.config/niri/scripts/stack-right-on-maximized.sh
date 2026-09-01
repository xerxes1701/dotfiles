#!/usr/bin/env bash
# Maximize the focused window to the screen edges, then take the window from the
# next column to the right and stack it on top as a full-size floating window.
#
# Bound to Mod+CTRL+M. Use case: a video maximized in the background with a
# semitransparent terminal floating over it.
#
# Override the floating size with env vars, e.g.
#   FLOAT_WIDTH=80% FLOAT_HEIGHT=90% stack-right-on-maximized.sh

set -euo pipefail

FLOAT_WIDTH="${FLOAT_WIDTH:-100%}"
FLOAT_HEIGHT="${FLOAT_HEIGHT:-100%}"

windows=$(niri msg -j windows)

focused=$(jq -c '(map(select(.is_focused)) | first) // empty' <<<"$windows")
[ -n "$focused" ] || exit 0
# Only makes sense when the focused window is tiled.
[ "$(jq -r '.is_floating' <<<"$focused")" = "false" ] || exit 0

fid=$(jq -r '.id' <<<"$focused")
ws=$(jq -r '.workspace_id' <<<"$focused")
col=$(jq -r '.layout.pos_in_scrolling_layout[0]' <<<"$focused")
width_before=$(jq -r '.layout.window_size[0]' <<<"$focused")

# Topmost window of the nearest column to the right, on the same workspace.
right=$(jq -r --argjson ws "$ws" --argjson col "$col" '
  [ .[]
    | select(.is_floating | not)
    | select(.workspace_id == $ws)
    | select(.layout.pos_in_scrolling_layout[0] > $col) ]
  | sort_by(.layout.pos_in_scrolling_layout)
  | first | .id // empty' <<<"$windows")

# maximize-window-to-edges is a toggle, so undo it again if the window was
# already maximized (it shrinks instead of growing).
niri msg action maximize-window-to-edges --id "$fid" >/dev/null
sleep 0.05
width_after=$(niri msg -j windows |
  jq -r --argjson id "$fid" '.[] | select(.id == $id) | .layout.window_size[0]')
if [ -n "$width_after" ] && [ "$width_after" -lt "$width_before" ]; then
  niri msg action maximize-window-to-edges --id "$fid" >/dev/null
fi

[ -n "$right" ] || exit 0

niri msg action move-window-to-floating --id "$right" >/dev/null
niri msg action set-window-width --id "$right" "$FLOAT_WIDTH" >/dev/null
niri msg action set-window-height --id "$right" "$FLOAT_HEIGHT" >/dev/null
niri msg action move-floating-window --id "$right" -x 0 -y 0 >/dev/null
niri msg action focus-window --id "$right" >/dev/null
