#!/bin/sh
# The working tree's changes in fzf: one file per line, its diff in the
# preview. Staged, not staged and untracked files are listed together;
# ignored ones are not. `git df` in .gitconfig.
#
# The preview starts in delta and switches to difftastic or git's own diff.
# Enter opens the file in nvim at the hunk on screen. fzf steps aside while
# nvim runs and comes back when it quits, on the same file in the same mode,
# so nothing has to be sent to the background for it. ctrl-z in nvim still
# stops the whole `git df`, and `fg` brings it back.
#
# Three measured details are why this is a script and not an alias:
#
#   jumping to a hunk   fzf cannot search the preview, and does not tell a
#                       command where the preview is scrolled to. What it
#                       can do is change-preview-window(+N), which puts line
#                       N at the top. So the position is kept here, in a
#                       state file, and every scroll key goes through this
#                       script. The mouse wheel does not: after scrolling
#                       with it, the next jump starts where the keys left
#                       the preview. The offset also outlives a move to
#                       another file, so focus resets it.
#   one rendering       the preview is rendered once, into a file that the
#                       preview shows and the jumps search. A hunk starts at
#                       the box delta draws around its • label, at @@ in
#                       git's diff, at "<path> --- " in difftastic's.
#   raw paths           git status -z, because without it git quotes a path
#                       with an umlaut as "Gr\303\266\303\237e". fzf is
#                       handed an index ({n}), and the path is looked up in
#                       a file, so no path goes through fzf's quoting. Paths
#                       with a newline or a tab in them are not supported.
#
# POSIX sh, like the other scripts here. Not on Windows yet: the alias says
# so there instead of failing on a missing script.

set -u

self=${0##*/}
tab=$(printf '\t')
esc=$(printf '\033')

err() { printf '%s: %s\n' "$self" "$*" >&2; }

usage() {
    cat <<EOF
usage: git df
       $self

lists the changed files of the working tree -- staged, not staged and
untracked -- in fzf, with the diff of the current one in the preview.

  enter               open the file in nvim, at the hunk on screen
  alt-d alt-t alt-g   the preview in delta, difftastic, git diff
  alt-n alt-p         next / previous hunk
  ctrl-d ctrl-u       half a page down / up
  ctrl-f ctrl-b       a page down / up
  shift-down/up       a line down / up
  esc                 quit

the mouse wheel scrolls too, but hunk jumps do not see where it went.
EOF
}

# --- state -----------------------------------------------------------------
# $DF_STATE is a directory made by the main run and inherited by everything
# fzf starts:
#   items    one line per listed file: status, path, path before a rename
#   state    the preview's mode, its top line, the hunk last jumped to (0:
#            none since the last scroll)
#   render   the preview as last rendered, after a key line: mode, path

load() { read -r mode offset hunk <"$DF_STATE/state"; }
save() { printf '%s %s %s\n' "$1" "$2" "$3" >"$DF_STATE/state"; }

# Item $1 of the list, counted from 0 like fzf's {n}.
item() {
    line=$(sed -n "$(($1 + 1))p" "$DF_STATE/items")
    xy=${line%%"$tab"*}
    rest=${line#*"$tab"}
    path=${rest%%"$tab"*}
    orig=${rest#*"$tab"}
}

# --- the list --------------------------------------------------------------
# A rename comes as two records, the new path and then the old one. Status
# letters are coloured the way git status colours them: the index green, the
# working tree red.

cmd_list() {
    git status --porcelain=v1 -z --untracked-files=all |
    tr '\0' '\n' |
    awk -v items="$DF_STATE/items" '
        BEGIN {
            e = "\033"; off = e "[0m"
            green = e "[32m"; red = e "[31m"; dim = e "[2m"
            printf "" >items
        }
        function emit(  x, y, show) {
            x = substr(xy, 1, 1); y = substr(xy, 2, 1)
            if (xy == "??") show = red xy off
            else show = (x == " " ? x : green x off) (y == " " ? y : red y off)
            print show "\t" path (orig == "" ? "" : dim " <- " orig off)
            print xy "\t" path "\t" orig >items
        }
        renamed { orig = $0; renamed = 0; emit(); next }
        { xy = substr($0, 1, 2); path = substr($0, 4); orig = "" }
        xy ~ /[RC]/ { renamed = 1; next }
        { emit() }
    '
}

# --- the preview -----------------------------------------------------------

# quotePath off for the same reason as status -z: in its diff headers git
# would otherwise print the umlaut path as "a/Gr\303\266\303\237e".
g() { git -c core.quotePath=false --no-pager "$@"; }

# git diff, with the arguments after $1, in the style $1 names.
diff_as() {
    style=$1
    shift
    case $style in
        delta)
            g diff --no-ext-diff "$@" |
            delta --paging never --width "$cols" --hunk-label '•' ;;
        difft)
            DFT_COLOR=always DFT_WIDTH=$cols \
            g -c diff.external=difft diff --ext-diff "$@" ;;
        git)
            g diff --no-ext-diff --color=always "$@" ;;
    esac
}

heading() { printf '%s[%sm%s%s[0m\n' "$esc" "$1" "$2" "$esc"; }

# The current item's diff in style $1: what is staged, then what is not.
# Untracked files and conflicts have one part only. $2 is diff_as, or raw
# for the plain unified diff that cmd_edit reads line numbers from.
render() {
    case $xy in
        '??')
            [ "$2" = raw ] || heading 31 untracked
            "$2" "$1" --no-index -- /dev/null "$path" ;;
        DD|AU|UD|UA|DU|AA|UU)
            [ "$2" = raw ] || heading 35 conflict
            "$2" "$1" -- "$path" ;;
        *)
            x=${xy%?}
            y=${xy#?}
            if [ "$x" != ' ' ]; then
                [ "$2" = raw ] || heading 32 staged
                if [ -n "$orig" ]; then
                    "$2" "$1" --cached -M -- "$orig" "$path"
                else
                    "$2" "$1" --cached -- "$path"
                fi
            fi
            if [ "$y" != ' ' ]; then
                if [ "$2" != raw ]; then
                    [ "$x" != ' ' ] && echo
                    heading 31 'not staged'
                fi
                "$2" "$1" -- "$path"
            fi ;;
    esac
}

raw() { shift; git --no-pager diff --no-ext-diff --no-color "$@"; }

cmd_preview() {
    item "$1"
    load
    cols=${FZF_PREVIEW_COLUMNS:-80}
    out=$DF_STATE/render.$$
    { printf '%s\t%s\n' "$mode" "$path"; render "$mode" diff_as 2>&1; } >"$out"
    tail -n +2 "$out"
    mv -f "$out" "$DF_STATE/render"
}

# --- moving in the preview -------------------------------------------------

# The preview lines that start a hunk, counted from 1 like
# change-preview-window(+N). Nothing when the rendering on file is of another
# file or mode: the preview has not caught up yet.
markers() {
    DF_WANT="$1$tab$2" DF_PATH="$2 --- " awk -v mode="$1" '
        NR == 1 { if ($0 != ENVIRON["DF_WANT"]) exit; next }
        { gsub(/\033\[[0-9;:]*[A-Za-z]/, ""); n = NR - 1 }
        mode == "git" && /^@@/ { print n }
        mode == "difft" && index($0, ENVIRON["DF_PATH"]) == 1 { print n }
        mode == "delta" { if (box && /^• /) print n - 1; box = /┐$/ }
    ' "$DF_STATE/render"
}

# Scrolling down stops once the last line is at the bottom. A hunk jump may
# go further, so the hunk is at the top -- fzf fills the rest with blank
# lines -- and from there down stays put instead of jumping back.
cmd_scroll() {
    [ -f "$DF_STATE/render" ] || return 0
    load
    lines=${FZF_PREVIEW_LINES:-20}
    case $1 in
        down)      by=1 ;;
        up)        by=-1 ;;
        half-down) by=$(((lines + 1) / 2)) ;;
        half-up)   by=$((-(lines + 1) / 2)) ;;
        page-down) by=$lines ;;
        page-up)   by=$((-lines)) ;;
        *)         return 0 ;;
    esac
    total=$(($(wc -l <"$DF_STATE/render") - 1))
    max=$((total - lines + 1))
    [ "$max" -lt "$offset" ] && max=$offset
    to=$((offset + by))
    [ "$to" -gt "$max" ] && to=$max
    [ "$to" -lt 1 ] && to=1
    save "$mode" "$to" 0
    echo "change-preview-window(+$to)"
}

# Without a jump since the last scroll, next goes to the first hunk below
# the top line and prev to the one the top line is in, as vim's ]c and [c.
cmd_hunk() {
    [ -f "$DF_STATE/render" ] || return 0
    item "$2"
    load
    marks=$(markers "$mode" "$path")
    [ -n "$marks" ] || return 0
    n=$(printf '%s\n' "$marks" | wc -l)
    # How many hunks start at or above the top line, and above it.
    at=$(printf '%s\n' "$marks" | awk -v o="$offset" '$1 <= o' | wc -l)
    above=$(printf '%s\n' "$marks" | awk -v o="$offset" '$1 < o' | wc -l)
    if [ "$1" = next ]; then
        if [ "$hunk" -gt 0 ]; then k=$((hunk + 1)); else k=$((at + 1)); fi
        [ "$k" -gt "$n" ] && k=$n
    else
        if [ "$hunk" -gt 0 ]; then k=$((hunk - 1)); else k=$above; fi
        [ "$k" -lt 1 ] && k=1
    fi
    to=$(printf '%s\n' "$marks" | sed -n "${k}p")
    save "$mode" "$to" "$k"
    echo "change-preview-window(+$to)+change-preview-label( $mode · hunk $k/$n )"
}

cmd_focus() {
    load
    if [ "$offset" != 1 ] || [ "$hunk" != 0 ]; then
        save "$mode" 1 0
        printf 'change-preview-window(+1)+'
    fi
    echo "change-preview-label( $mode )"
}

cmd_mode() {
    save "$1" 1 0
    echo "change-preview-label( $1 )+change-preview-window(+1)+refresh-preview"
}

# --- nvim ------------------------------------------------------------------
# At the first changed line of the hunk on screen. The hunk is counted in
# git's diff, which delta draws hunk for hunk; difftastic finds hunks of its
# own, so there the line is the git hunk with the same number, which is near
# but not always the same place.

cmd_edit() {
    item "$1"
    load
    if [ ! -f "$path" ]; then
        printf '%s is not in the working tree. enter goes back.\n' "$path"
        read -r _
        return 0
    fi
    k=$hunk
    if [ "$k" -eq 0 ] && [ -f "$DF_STATE/render" ]; then
        k=$(markers "$mode" "$path" | awk -v o="$offset" '$1 <= o' | wc -l)
    fi
    [ "$k" -lt 1 ] && k=1
    line=$(render - raw | awk -v k="$k" '
        /^@@/ {
            if (h >= k) exit
            h++; first = 0; ln = 1; comb = /^@@@/
            for (i = 2; i <= NF; i++)
                if ($i ~ /^\+[0-9]/) {
                    split(substr($i, 2), p, ",")
                    ln = p[1] + 0
                    break
                }
            at = ln
            next
        }
        h && !first && !comb {
            c = substr($0, 1, 1)
            if (c == "+" || c == "-") { at = ln; first = 1 }
            else if (c == " ") ln++
        }
        END { print (at > 0 ? at : 1) }
    ')
    exec nvim "+$line" -- "$path"
}

# --- main ------------------------------------------------------------------

keys="enter nvim · alt-d/t/g delta/difft/git · alt-n/p next/previous hunk
ctrl-d/u half page · ctrl-f/b page · shift-down/up line · esc quit"

main() {
    # Resolved before the cd below, so a relative $0 still finds this file.
    DF_SELF=$(readlink -f -- "$0") || { err "cannot resolve $0"; exit 1; }
    top=$(git rev-parse --show-toplevel) || exit 1
    cd "$top" || exit 1

    DF_STATE=$(mktemp -d) || { err "cannot create a temporary directory"; exit 1; }
    export DF_SELF DF_STATE
    trap 'rm -rf -- "$DF_STATE"' EXIT
    trap 'exit 130' INT TERM HUP

    save delta 1 0
    cmd_list >"$DF_STATE/list"
    if [ ! -s "$DF_STATE/list" ]; then
        echo "nothing to diff: the working tree is clean"
        exit 0
    fi

    # --no-height and the preview window override FZF_DEFAULT_OPTS, which
    # asks for 40% of the screen and the preview on the right.
    fzf --ansi --no-height --with-shell 'sh -c' \
        --delimiter "$tab" --nth 2.. --tabstop 3 \
        --header "$keys" \
        --preview '"$DF_SELF" preview {n}' \
        --preview-window 'up,70%' --preview-label ' delta ' \
        --bind 'focus:transform:"$DF_SELF" focus' \
        --bind 'alt-d:transform:"$DF_SELF" mode delta' \
        --bind 'alt-t:transform:"$DF_SELF" mode difft' \
        --bind 'alt-g:transform:"$DF_SELF" mode git' \
        --bind 'alt-n:transform:"$DF_SELF" hunk next {n}' \
        --bind 'alt-p:transform:"$DF_SELF" hunk prev {n}' \
        --bind 'ctrl-d:transform:"$DF_SELF" scroll half-down' \
        --bind 'ctrl-u:transform:"$DF_SELF" scroll half-up' \
        --bind 'ctrl-f:transform:"$DF_SELF" scroll page-down' \
        --bind 'ctrl-b:transform:"$DF_SELF" scroll page-up' \
        --bind 'shift-down:transform:"$DF_SELF" scroll down' \
        --bind 'shift-up:transform:"$DF_SELF" scroll up' \
        --bind 'enter:execute("$DF_SELF" edit {n})+reload("$DF_SELF" list)' \
        <"$DF_STATE/list"
    rc=$?
    # 130 is esc, the way out; enter never accepts.
    case $rc in 0|1|130) exit 0 ;; esac
    exit "$rc"
}

# --- dispatch --------------------------------------------------------------
# Everything but the main run is called by fzf, with $DF_STATE set.

case ${1-} in
    '')        main ;;
    -h|--help) usage ;;
    list|preview|scroll|hunk|focus|mode|edit)
        if [ -z "${DF_STATE-}" ]; then
            err "$1 is called by fzf -- run git df"
            exit 2
        fi
        cmd=$1
        shift
        "cmd_$cmd" "$@" ;;
    *)
        err "unknown argument: $1"
        usage >&2
        exit 2 ;;
esac
