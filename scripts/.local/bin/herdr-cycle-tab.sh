#!/usr/bin/env bash
# Focus the next or previous tab in the active herdr workspace.
#
# tmux binds prefix+Tab to next-window and nvim binds <leader><Tab> to the
# next tab page, so "Tab means tab" holds at every level of the unified
# navigation scheme. herdr's own next_tab and previous_tab actions take one
# key each and already carry prefix+n and prefix+p, and herdr has no aliasing
# in config.toml -- hence this, bound as a `type = "shell"` custom command.
#
# `herdr tab focus` wants an explicit tab id, so the order comes from
# `herdr tab list`, which returns the tabs of a workspace in tab-bar order.
# Wraps at both ends, as tmux's next-window and nvim's tabnext do.
#
# Usage: herdr-cycle-tab.sh <next|prev>
set -uo pipefail

case ${1:-} in
    next) step=1 ;;
    prev) step=-1 ;;
    *) printf 'herdr-cycle-tab.sh: usage: %s <next|prev>\n' "${0##*/}" >&2; exit 2 ;;
esac

herdr=${HERDR_BIN_PATH:-herdr}
ws=${HERDR_ACTIVE_WORKSPACE_ID:-}
cur=${HERDR_ACTIVE_TAB_ID:-}

[ -n "$ws" ] && [ -n "$cur" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

mapfile -t tabs < <("$herdr" tab list --workspace "$ws" 2>/dev/null \
    | jq -r '.result.tabs[]?.tab_id')
[ "${#tabs[@]}" -gt 1 ] || exit 0

for i in "${!tabs[@]}"; do
    if [ "${tabs[i]}" = "$cur" ]; then
        exec "$herdr" tab focus "${tabs[(i + step + ${#tabs[@]}) % ${#tabs[@]}]}"
    fi
done
