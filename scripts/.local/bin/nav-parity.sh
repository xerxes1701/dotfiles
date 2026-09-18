#!/usr/bin/env bash
# Report drift in the unified navigation scheme across nvim, tmux, herdr and
# zellij.
#
# The scheme's whole value is that one set of fingers works in nvim, in any of
# the three multiplexers, and in any of them with nvim inside it. Nothing in the
# four config formats enforces that, and herdr cannot even include a shared file
# -- its keys are duplicated between herdr/ and .herdr-devcontainer/ on purpose
# (see the README). So this asks each tool to enumerate itself, the way
# shell-parity.sh does, rather than regex-parsing four dialects:
#
#   nvim    keybindings.yaml, the inventory the config's own CLAUDE.md requires
#           to be updated alongside every keymap change
#   tmux    `tmux list-keys` on a throwaway server started from the real config,
#           which is the only way to see what tpm's plugins end up binding
#   herdr   `herdr config check`, plus the [keys] table of both configs
#   zellij  the one that cannot: it has no list-keys, and `setup --check` only
#           says whether the file parses. So its keys are read out of the KDL
#           after all -- which is why it, alone, is also checked in the other
#           direction, for keys it binds that the table never named.
#
# Exits non-zero if any row of the table below is missing on a side that is
# supposed to have it, if the two herdr configs disagree, or if zellij has
# drifted away from the table in either direction.

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
herdr_win=$root/.herdr-windows/.config/herdr/config.toml
zellij_conf=$root/zellij/.config/zellij/config.kdl
nav_setup=$root/scripts/.local/bin/nav-setup.sh

# --- the table -------------------------------------------------------------
# action | nvim key | tmux key | tmux key-table | herdr key | zellij mode |
# zellij key. zellij is modal rather than prefixed, so it needs the same
# key-plus-table pair tmux does: "tmux" is the mode Ctrl a switches to (the
# name is zellij's, it ships the mode as a tmux emulation), "shared" is its
# shared_except "locked" block, and "locked" is what it starts in.
# "n/a" means this side has no equivalent, and that this is intended (and it
# is spelled that way, not "-", because "-" is tmux's literal split-below key):
#   equalize panes    herdr has no equalize action, only its resize mode
#   the session rows   zellij can only pick a session and detach; it has no
#                      action for cycling, creating, renaming or killing one
#                      from inside a session
#   session movement,
#   rename, detach    nvim has no session to move between, rename or detach
#   workspace, agent  the direct alt chords and the agent panel are
#                     herdr's alone: the prefix rows above are what tmux and
#                     nvim match, these are the accelerators on top
ROWS=(
    "focus left        | <C-h>          | C-h     | root   | ctrl+h            | shared | Ctrl h"
    "focus down        | <C-j>          | C-j     | root   | ctrl+j            | shared | Ctrl j"
    "focus up          | <C-k>          | C-k     | root   | ctrl+k            | shared | Ctrl k"
    "focus right       | <C-l>          | C-l     | root   | ctrl+l            | shared | Ctrl l"
    "resize left       | <C-Left>       | C-Left  | root   | ctrl+left         | shared | Ctrl Left"
    "resize down       | <C-Down>       | C-Down  | root   | ctrl+down         | shared | Ctrl Down"
    "resize up         | <C-Up>         | C-Up    | root   | ctrl+up           | shared | Ctrl Up"
    "resize right      | <C-Right>      | C-Right | root   | ctrl+right        | shared | Ctrl Right"
    "previous pane     | <C-\\>          | \\\\      | prefix | prefix+backslash  | tmux   | \\\\"
    "prefix            | n/a            | n/a     | prefix | ctrl+a            | shared | Ctrl a"
    "literal prefix    | n/a            | C-a     | prefix | n/a               | tmux   | Ctrl a"
    "split right       | <leader>sv     | v       | prefix | prefix+v          | tmux   | v"
    "split below       | <leader>s-     | -       | prefix | prefix+minus      | tmux   | -"
    "close pane        | <leader>sx     | X       | prefix | prefix+shift+x    | tmux   | X"
    "zoom pane         | <leader>sz     | z       | prefix | prefix+z          | tmux   | z"
    "equalize panes    | <leader>se     | e       | prefix | n/a               | n/a    | n/a"
    "cycle pane        | <leader>so     | o       | prefix | prefix+o          | tmux   | o"
    "cycle pane back   | n/a            | O       | prefix | prefix+shift+o    | tmux   | O"
    "rename pane       | n/a            | n/a     | prefix | prefix+shift+p    | tmux   | P"
    "resize mode       | n/a            | n/a     | prefix | prefix+r          | tmux   | r"
    "move mode         | n/a            | n/a     | prefix | n/a               | tmux   | m"
    "edit scrollback   | n/a            | n/a     | prefix | prefix+e          | tmux   | e"
    "copy mode         | n/a            | [       | prefix | n/a               | tmux   | ["
    "new tab           | <leader>tc     | c       | prefix | prefix+c          | tmux   | c"
    "next tab          | <leader>tn     | n       | prefix | prefix+n          | tmux   | n"
    "previous tab      | <leader>tp     | p       | prefix | prefix+p          | tmux   | p"
    "next tab (Tab)    | <leader><Tab>  | Tab     | prefix | prefix+tab        | tmux   | Tab"
    "prev tab (S-Tab)  | <leader><S-Tab>| BTab    | prefix | prefix+shift+tab  | tmux   | Shift Tab"
    "close tab         | <leader>tx     | C-x     | prefix | prefix+ctrl+x     | tmux   | Ctrl x"
    "rename tab        | n/a            | ,       | prefix | prefix+comma      | tmux   | ,"
    "tab 1..9          | <leader>1      | 1       | prefix | prefix+1..9       | tmux   | 1"
    "session picker    | <leader>ww     | w       | prefix | prefix+w          | tmux   | w"
    "next session      | n/a            | j       | prefix | prefix+j          | n/a    | n/a"
    "previous session  | n/a            | k       | prefix | prefix+k          | n/a    | n/a"
    "next workspace    | n/a            | n/a     | prefix | alt+j             | n/a    | n/a"
    "prev workspace    | n/a            | n/a     | prefix | alt+k             | n/a    | n/a"
    "next agent        | n/a            | n/a     | prefix | alt+shift+j       | n/a    | n/a"
    "prev agent        | n/a            | n/a     | prefix | alt+shift+k       | n/a    | n/a"
    "new session       | <leader>wN     | N       | prefix | prefix+shift+n    | n/a    | n/a"
    "rename session    | n/a            | W       | prefix | prefix+shift+w    | n/a    | n/a"
    "close session     | <leader>wD     | D       | prefix | prefix+shift+d    | n/a    | n/a"
    "detach            | n/a            | Q       | prefix | prefix+shift+q    | tmux   | Q"
    "help              | <leader>?      | ?       | prefix | prefix+?          | tmux   | ?"
    "lock              | n/a            | n/a     | prefix | n/a               | shared | Ctrl z"
    "unlock            | n/a            | n/a     | prefix | n/a               | locked | Ctrl z"
    "quit              | n/a            | n/a     | prefix | n/a               | shared | Ctrl q"
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

# zellij: the KDL, because there is nothing to ask. Every key of every bind
# line, tagged with the block it sits in, because the same key means different
# things in different modes -- x closes a pane in zellij's own pane mode and a
# tab in its tab mode. A bind can name several keys at once (bind "h" "Left"),
# so each one becomes its own line.
zellij_keys() {
    awk '
        /^keybinds/ { in_kb = 1 }
        !in_kb { next }
        /^    [a-z_]+/ {
            mode = $1
            if (mode == "shared_except") {
                m = $2; gsub(/"/, "", m)
                mode = (m == "locked") ? "shared" : "shared_" m
            }
            next
        }
        /^ *bind "/ {
            line = $0
            sub(/\{.*/, "", line)
            while (match(line, /"[^"]*"/)) {
                printf "%s\t%s\n", mode, substr(line, RSTART + 1, RLENGTH - 2)
                line = substr(line, RSTART + RLENGTH)
            }
        }
    ' "$1"
}
zellij_keys "$zellij_conf" > "$tmp/zellij"
printf '  zellij %d bindings in config.kdl\n' "$(wc -l < "$tmp/zellij")"

# --- the rows --------------------------------------------------------------
printf '\n== scheme ==\n'
for row in "${ROWS[@]}"; do
    IFS='|' read -r action nkey tkey ttable hkey zmode zkey <<< "$row"
    action=$(trim "$action"); nkey=$(trim "$nkey")
    tkey=$(trim "$tkey"); ttable=$(trim "$ttable"); hkey=$(trim "$hkey")
    zmode=$(trim "$zmode"); zkey=$(trim "$zkey")

    # What the table claims zellij binds, in the form zellij_keys emits, for the
    # other-direction check below.
    [ "$zkey" = "n/a" ] || printf '%s\t%s\n' "$zmode" "$zkey" >> "$tmp/rows.zellij"

    printf '  %-18s' "$action"
    for side in nvim tmux herdr zellij; do
        case $side in
            nvim)   key=$nkey; file=$tmp/nvim ;;
            tmux)   key=$tkey; file=$tmp/tmux.$ttable ;;
            herdr)  key=$hkey; file=$tmp/herdr ;;
            zellij) key=$zkey; file=$tmp/zellij
                    [ "$key" = "n/a" ] || key=$(printf '%s\t%s' "$zmode" "$zkey") ;;
        esac
        if [ "$key" = "n/a" ]; then
            printf ' %s n/a          ' "$side"
        elif grep -qxF -- "$key" "$file"; then
            printf ' %s ok           ' "$side"
        else
            printf ' %s MISSING(%s)' "$side" "${key#*	}"
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

# The windows config binds the same keys to different commands on purpose --
# the .ps1 twins through pwsh, since cmd.exe cannot run the bash scripts -- and
# says so in comments of its own. So it is compared with the `command =` lines,
# the comments and the blank lines taken out: the keys must agree, the
# commands may not. `type =` goes with them, because layer 0 differs in the
# mechanism as well: the host reaches a plugin_action, and windows a shell
# command, since smart-splits.nvim's herdr plugin is linux and macos only.
block_keys() { block "$1" | grep -vE '^[[:space:]]*(#|$)|^(command|type) = '; }
if diff -q <(block_keys "$herdr_host") <(block_keys "$herdr_win") >/dev/null; then
    printf '  keys block   identical in herdr/ and .herdr-windows/ (commands aside)\n'
else
    printf '  keys block   DRIFT between herdr/ and .herdr-windows/:\n'
    diff <(block_keys "$herdr_host") <(block_keys "$herdr_win") | sed 's/^/               /'
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

# --- the zellij config -----------------------------------------------------
# Two checks the other three do not need. The first is the counterpart of
# `herdr config check`: zellij's own parser, which is the only thing that will
# say a key name is misspelt -- a bind zellij cannot parse takes the whole file
# down, not just that line.
printf '\n== zellij ==\n'
if command -v zellij >/dev/null 2>&1; then
    if out=$(zellij --config "$zellij_conf" setup --check 2>&1 \
             | grep -F '[CONFIG FILE]'); then
        printf '  config check %s\n' "$(trim "${out#*: }")"
    else
        printf '  config check FAIL\n'
        zellij --config "$zellij_conf" setup --check 2>&1 \
            | sed 's/^/               /'
        status=1
    fi
else
    printf '  config check skipped, no zellij on PATH\n'
fi

# The second runs the table backwards. Every other side is a config written
# against the scheme; zellij's is a stock dump with the scheme laid over it, and
# a key added there alone would pass every check above by simply not being
# looked for. So: everything its prefix mode binds, and every ctrl key its
# shared and locked blocks bind, has to be a row of the table.
#
# The digits are the exception the 1..9 row already covers.
unlisted=0
while IFS=$'\t' read -r mode key; do
    case $mode in
        tmux) ;;
        shared|locked) case $key in "Ctrl "*) ;; *) continue ;; esac ;;
        *) continue ;;
    esac
    case $key in [2-9]) continue ;; esac
    # Layer 0 is bound in locked as well as everywhere else, on purpose; the
    # table lists it once, under shared.
    grep -qxF -- "$(printf '%s\t%s' "$mode" "$key")" "$tmp/rows.zellij" && continue
    [ "$mode" = locked ] \
        && grep -qxF -- "$(printf 'shared\t%s' "$key")" "$tmp/rows.zellij" \
        && continue
    printf '  unlisted     %s mode binds %s, and no row says so\n' "$mode" "$key"
    unlisted=1
    status=1
done < "$tmp/zellij"
[ "$unlisted" -eq 0 ] \
    && printf '  unlisted     nothing, every key it binds has a row\n'

# Layer 0 is the one thing that must work before the unlock, since a locked
# zellij is what a fresh session is.
missing_locked=
while IFS=$'\t' read -r mode key; do
    [ "$mode" = shared ] || continue
    case $key in "Ctrl "[hjkl]|"Ctrl Left"|"Ctrl Down"|"Ctrl Up"|"Ctrl Right") ;;
        *) continue ;;
    esac
    grep -qxF -- "$(printf 'locked\t%s' "$key")" "$tmp/zellij" \
        || missing_locked="$missing_locked $key"
done < "$tmp/rows.zellij"
if [ -z "$missing_locked" ]; then
    printf '  layer 0      bound in locked mode too\n'
else
    printf '  layer 0      NOT bound in locked mode:%s\n' "$missing_locked"
    status=1
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

# zellij is the fourth consumer and the odd one: this checkout has no back-end
# for it, so its layer 0 comes from vim-zellij-navigator instead. Pinned by
# version and checksum in nav-setup.sh, which is also what installs it, so the
# pin is read out of there rather than repeated here.
vzn_sha256=$(sed -n 's/^vzn_sha256=//p' "$nav_setup")
vzn_version=$(sed -n 's/^vzn_version=//p' "$nav_setup")
vzn=$HOME/.local/share/zellij/plugins/vim-zellij-navigator.wasm
if [ ! -f "$vzn" ]; then
    printf '  navigator    MISSING at %s -- run nav-setup.sh\n' "$vzn"
    status=1
elif [ "$(sha256sum "$vzn" | cut -d' ' -f1)" = "$vzn_sha256" ]; then
    printf '  navigator    at the pinned %s\n' "$vzn_version"
else
    printf '  navigator    not the pinned %s -- run nav-setup.sh\n' "$vzn_version"
    status=1
fi

# Installed is not the same as allowed. A zellij plugin has to be granted its
# permissions once per machine, at a (y/n) prompt raised the first time it is
# messaged -- and until someone answers it, ctrl+hjkl loads the plugin and
# nothing else happens, which looks exactly like a missing binding. zellij
# records the answer here.
zellij_perms=${XDG_CACHE_HOME:-$HOME/.cache}/zellij/permissions.kdl
if grep -qs 'vim-zellij-navigator' "$zellij_perms"; then
    printf '  navigator    permissions granted\n'
else
    printf '  navigator    permissions NOT granted -- press ctrl+h in zellij once\n'
    printf '               and answer y; until then layer 0 is dead there\n'
    status=1
fi

printf '\n'
if [ "$status" -eq 0 ]; then
    printf 'navigation is in sync.\n'
else
    printf 'navigation has drifted.\n'
fi
exit "$status"
