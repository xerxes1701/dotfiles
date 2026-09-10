#!/usr/bin/env bash
# Focus the next or previous herdr workspace.
#
# The workspace level of the unified navigation scheme has two entry points:
# alt+j / alt+k directly, and C-a j / C-a k on the prefix. herdr binds one key
# per action, and the direct chords have next_workspace and previous_workspace,
# so the prefix form goes through this instead. It is worth keeping: C-a j /
# C-a k is the form tmux also has (switch-client -n / -p), so the portable
# level ladder stays intact.
#
# `herdr workspace focus` wants an explicit id, so the order comes from
# `herdr workspace list`, which returns them in sidebar order. Wraps at both
# ends, as tmux's switch-client does.
#
# Same shape as herdr-cycle-tab.sh; see that file's header for the rest.
#
# Usage: herdr-cycle-workspace.sh <next|prev>
set -uo pipefail

case ${1:-} in
    next) step=1 ;;
    prev) step=-1 ;;
    *) printf 'herdr-cycle-workspace.sh: usage: %s <next|prev>\n' "${0##*/}" >&2; exit 2 ;;
esac

herdr=${HERDR_BIN_PATH:-herdr}
cur=${HERDR_ACTIVE_WORKSPACE_ID:-}

[ -n "$cur" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

mapfile -t spaces < <("$herdr" workspace list 2>/dev/null \
    | jq -r '.result.workspaces[]?.workspace_id')
[ "${#spaces[@]}" -gt 1 ] || exit 0

for i in "${!spaces[@]}"; do
    if [ "${spaces[i]}" = "$cur" ]; then
        exec "$herdr" workspace focus "${spaces[(i + step + ${#spaces[@]}) % ${#spaces[@]}]}"
    fi
done
