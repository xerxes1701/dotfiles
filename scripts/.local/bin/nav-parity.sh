#!/usr/bin/env bash
# Report drift in the unified navigation scheme across nvim, tmux and herdr.
#
# The scheme's whole value is that one set of fingers works in nvim, in tmux,
# in herdr and in either multiplexer with nvim inside it. Nothing in the three
# config formats enforces that, and herdr cannot even include a shared file --
# its keys are duplicated between herdr/ and .herdr-devcontainer/ on purpose
# (see the README). So this asks each tool to enumerate itself, the way
# shell-parity.sh does, rather than regex-parsing three dialects:
#
#   nvim   keybindings.yaml, the inventory the config's own CLAUDE.md requires
#          to be updated alongside every keymap change
#   tmux   `tmux list-keys` on a throwaway server started from the real config,
#          which is the only way to see what tpm's plugins end up binding
#   herdr  `herdr config check`, plus the [keys] table of both configs
#
# Exits non-zero if any row of the table below is missing on a side that is
# supposed to have it, or if the two herdr configs disagree.

set -uo pipefail

# readlink -f, so this still finds the repository when the script is reached
# through the symlink that stowing `scripts` puts in ~/.local/bin. This file
# lives in scripts/.local/bin, three levels below the repository.
root=$(cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")/../../.." && pwd) \
    || exit 1
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"; tmux -L navparity kill-server 2>/dev/null' EXIT

status=0
nvim_yaml=$root/nvim/.config/nvim/keybindings.yaml
tmux_conf=$root/tmux/.config/tmux/tmux.conf
herdr_host=$root/herdr/.config/herdr/config.toml
herdr_dc=$root/.herdr-devcontainer/.config/herdr/config.toml

# --- the table -------------------------------------------------------------
# action | nvim key | tmux key | tmux key-table | herdr key
# "n/a" means this side has no equivalent, and that this is intended (and it
# is spelled that way, not "-", because "-" is tmux's literal split-below key):
#   equalize panes    herdr has no equalize action, only its resize mode
#   session movement,
#   rename, detach    nvim has no session to move between, rename or detach
#   workspace, agent  the direct ctrl+shift chords and the agent panel are
#                     herdr's alone: the prefix rows above are what tmux and
#                     nvim match, these are the accelerators on top
ROWS=(
    "focus left        | <C-h>          | C-h     | root   | ctrl+h"
    "focus down        | <C-j>          | C-j     | root   | ctrl+j"
    "focus up          | <C-k>          | C-k     | root   | ctrl+k"
    "focus right       | <C-l>          | C-l     | root   | ctrl+l"
    "resize left       | <C-Left>       | C-Left  | root   | ctrl+left"
    "resize down       | <C-Down>       | C-Down  | root   | ctrl+down"
    "resize up         | <C-Up>         | C-Up    | root   | ctrl+up"
    "resize right      | <C-Right>      | C-Right | root   | ctrl+right"
    "previous pane     | <C-\\>          | \\\\      | prefix | prefix+backslash"
    "split right       | <leader>sv     | v       | prefix | prefix+v"
    "split below       | <leader>s-     | -       | prefix | prefix+minus"
    "close pane        | <leader>sx     | x       | prefix | prefix+x"
    "zoom pane         | <leader>sz     | z       | prefix | prefix+z"
    "equalize panes    | <leader>se     | e       | prefix | n/a"
    "cycle pane        | <leader>so     | o       | prefix | prefix+o"
    "new tab           | <leader>tc     | c       | prefix | prefix+c"
    "next tab          | <leader>tn     | n       | prefix | prefix+n"
    "previous tab      | <leader>tp     | p       | prefix | prefix+p"
    "next tab (Tab)    | <leader><Tab>  | Tab     | prefix | prefix+tab"
    "prev tab (S-Tab)  | <leader><S-Tab>| BTab    | prefix | prefix+shift+tab"
    "close tab         | <leader>tx     | X       | prefix | prefix+shift+x"
    "session picker    | <leader>ww     | w       | prefix | prefix+w"
    "next session      | n/a            | j       | prefix | prefix+j"
    "previous session  | n/a            | k       | prefix | prefix+k"
    "next workspace    | n/a            | n/a     | prefix | ctrl+shift+j"
    "prev workspace    | n/a            | n/a     | prefix | ctrl+shift+k"
    "next agent        | n/a            | n/a     | prefix | ctrl+alt+shift+j"
    "prev agent        | n/a            | n/a     | prefix | ctrl+alt+shift+k"
    "new session       | <leader>wN     | N       | prefix | prefix+shift+n"
    "rename session    | n/a            | W       | prefix | prefix+shift+w"
    "close session     | <leader>wD     | D       | prefix | prefix+shift+d"
    "detach            | n/a            | Q       | prefix | prefix+shift+q"
    "help              | <leader>?      | ?       | prefix | prefix+?"
)

trim() { printf '%s' "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'; }

# --- collect what each side actually binds ---------------------------------
printf '== collecting ==\n'

# nvim: the inventory, not the running editor. verify/verify.sh is what proves
# the config matches it; CLAUDE.md makes updating it part of every change.
if ! yq -r '.keybindings[].key' "$nvim_yaml" > "$tmp/nvim" 2>"$tmp/nvim.err"; then
    printf '  nvim   FAIL  could not read %s\n' "$nvim_yaml"
    sed 's/^/         /' "$tmp/nvim.err"
    exit 1
fi
printf '  nvim   %d explicit bindings in keybindings.yaml\n' "$(wc -l < "$tmp/nvim")"

# tmux: a private socket and a throwaway session, so this never touches a
# server the user is working in. The config sources tpm, so this sees the
# plugin bindings too -- which is the point, smart-splits.nvim installs eight
# of the rows above.
if ! tmux -L navparity -f "$tmux_conf" new-session -d -s navparity 2>"$tmp/tmux.err"; then
    printf '  tmux   FAIL  config did not load\n'
    sed 's/^/         /' "$tmp/tmux.err"
    exit 1
fi
sleep 1
tmux -L navparity list-keys -T root \
    | sed -n 's/^bind-key  *-T root  *\([^ ]*\).*/\1/p'   > "$tmp/tmux.root"
tmux -L navparity list-keys -T prefix \
    | sed -n 's/^bind-key  *-T prefix  *\([^ ]*\).*/\1/p' > "$tmp/tmux.prefix"
printf '  tmux   %d root, %d prefix bindings\n' \
    "$(wc -l < "$tmp/tmux.root")" "$(wc -l < "$tmp/tmux.prefix")"

# herdr: every quoted value in the [keys] table plus every custom command key.
# Both answer "what key runs this", so one list answers the table's question.
keys_of() {
    sed -n '/^\[keys\]/,$p' "$1" \
        | grep -oE '^[a-z_]+ = "[^"]+"|^key = "[^"]+"' \
        | sed 's/.*= "//; s/"$//'
}
keys_of "$herdr_host" > "$tmp/herdr"
printf '  herdr  %d bindings in the host config\n' "$(wc -l < "$tmp/herdr")"

# --- the rows --------------------------------------------------------------
printf '\n== scheme ==\n'
for row in "${ROWS[@]}"; do
    IFS='|' read -r action nkey tkey ttable hkey <<< "$row"
    action=$(trim "$action"); nkey=$(trim "$nkey")
    tkey=$(trim "$tkey"); ttable=$(trim "$ttable"); hkey=$(trim "$hkey")

    printf '  %-18s' "$action"
    for side in nvim tmux herdr; do
        case $side in
            nvim)  key=$nkey; file=$tmp/nvim ;;
            tmux)  key=$tkey; file=$tmp/tmux.$ttable ;;
            herdr) key=$hkey; file=$tmp/herdr ;;
        esac
        if [ "$key" = "n/a" ]; then
            printf ' %s n/a          ' "$side"
        elif grep -qxF -- "$key" "$file"; then
            printf ' %s ok           ' "$side"
        else
            printf ' %s MISSING(%s)' "$side" "$key"
            status=1
        fi
    done
    printf '\n'
done

# --- the two herdr configs -------------------------------------------------
printf '\n== herdr configs ==\n'
block() { sed -n '/^# --- unified navigation scheme/,$p' "$1"; }
if diff -q <(block "$herdr_host") <(block "$herdr_dc") >/dev/null; then
    printf '  keys block   identical in herdr/ and .herdr-devcontainer/\n'
else
    printf '  keys block   DRIFT between herdr/ and .herdr-devcontainer/:\n'
    diff <(block "$herdr_host") <(block "$herdr_dc") | sed 's/^/               /'
    status=1
fi

if command -v herdr >/dev/null 2>&1; then
    if out=$(herdr config check 2>&1); then
        printf '  config check %s\n' "$out"
    else
        printf '  config check FAIL\n'
        printf '%s\n' "$out" | sed 's/^/               /'
        status=1
    fi
else
    printf '  config check skipped, no herdr on PATH\n'
fi

# --- the shared checkout ---------------------------------------------------
# nvim pins smart-splits.nvim, tmux sources the tmux side out of that same
# checkout and herdr's plugin is linked against it. If the link is stale or the
# checkout is gone, ctrl+hjkl silently stops crossing app boundaries.
printf '\n== smart-splits.nvim ==\n'
checkout=$HOME/.local/share/nvim/lazy/smart-splits.nvim
pinned=$(grep -oP 'commit = "\K[0-9a-f]{40}' \
    "$root/nvim/.config/nvim/lua/plugins/smart-splits.lua")
if [ -d "$checkout" ]; then
    head=$(git -C "$checkout" rev-parse HEAD 2>/dev/null)
    if [ "$head" = "$pinned" ]; then
        printf '  checkout     at the pinned commit %s\n' "${pinned:0:12}"
    else
        printf '  checkout     at %s, spec pins %s -- run :Lazy restore\n' \
            "${head:0:12}" "${pinned:0:12}"
        status=1
    fi
else
    printf '  checkout     MISSING at %s -- tmux and herdr both source it\n' "$checkout"
    status=1
fi
if command -v herdr >/dev/null 2>&1; then
    if herdr plugin list 2>/dev/null | grep -q 'smart-splits.nvim.*enabled'; then
        printf '  herdr plugin linked and enabled\n'
    else
        printf '  herdr plugin NOT linked -- run: herdr plugin link %s\n' "$checkout"
        status=1
    fi
fi

printf '\n'
if [ "$status" -eq 0 ]; then
    printf 'navigation is in sync.\n'
else
    printf 'navigation has drifted.\n'
fi
exit "$status"
