#!/bin/sh
# Changes in fzf, with the diff of the current line in the preview. Behind
# two aliases in .gitconfig:
#
#   git df   the working tree: one line per changed file -- staged, not
#            staged and untracked, not the ignored ones.
#   git sh   the history, drawn as git lg draws it. Enter on a commit lists
#            its files in a second fzf; esc there goes back to the history,
#            where it was, and ctrl-c ends both. Given one commit and
#            nothing else -- a hash, HEAD, a branch, HEAD~2 -- git sh lists
#            that commit's files straight away, and esc quits.
#
# Every list has the same preview: delta to begin with, difftastic or git's
# own diff on a key, hunk jumps and scrolling. Enter on a file opens it in
# nvim at the hunk on screen -- in git df the file itself, in git sh the
# file as that commit has it, read-only. fzf steps aside while nvim runs and
# comes back when it quits, so nothing has to be sent to the background for
# it. ctrl-z in nvim still stops everything, and `fg` brings it back.
#
# A merge is shown against its first parent, as what it brought in. Plain
# `git show` gives a combined diff, which for a clean merge has no files.
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
#                       another line, so focus resets it.
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
# POSIX sh, like the other scripts here. Not on Windows yet: the aliases say
# so there instead of failing on a missing script.

set -u

self=${0##*/}
tab=$(printf '\t')
esc=$(printf '\033')

err() { printf '%s: %s\n' "$self" "$*" >&2; }

usage() {
    cat <<EOF
usage: git df                      the working tree's changes
       git sh [log options]        the history, then a commit's files
       git sh <commit>             that commit's files
       $self [show [<commit> | log options]]

  enter               git df: open the file in nvim at the hunk on screen
                      git sh: the commit's files; there, open the file as
                      the commit has it, read-only
  alt-d alt-t alt-g   the preview in delta, difftastic, git diff
  alt-n alt-p         next / previous hunk
  ctrl-d ctrl-u       half a page down / up
  ctrl-f ctrl-b       a page down / up
  shift-down/up       a line down / up
  esc                 quit; in a commit's files, back to the history
  ctrl-c              quit, from the files as well

git sh hands its options to git log: \`git sh -- src/\`, \`git sh main..\`.
one commit alone -- \`git sh HEAD\`, a hash, a branch, HEAD~2 -- opens its
files, where esc quits; \`git sh main --\` is the history from it.
the mouse wheel scrolls too, but hunk jumps do not see where it went.
EOF
}

# --- state -----------------------------------------------------------------
# Every fzf has a directory of its own, $DF_STATE, which everything it starts
# inherits, together with:
#   DF_KIND    worktree (git df), commits or files (git sh)
#   DF_COMMIT  for files: the commit
#   DF_PARENT  for files: the history's directory
# In the directory:
#   items    one line per list line: the status (in the history: the
#            commit, or nothing on a line that is all graph), the path, the
#            path before a rename
#   state    the preview's mode, its top line, the hunk last jumped to (0:
#            none since the last scroll)
#   render   the preview as last rendered, after a key line: mode, id
#   quit     in the history's directory: ctrl-c was pressed in the files

load() { read -r mode offset hunk <"$DF_STATE/state"; }
save() { printf '%s %s %s\n' "$1" "$2" "$3" >"$DF_STATE/state"; }

# Item $1 of the list, counted from 0 like fzf's {n}. $id is what the
# preview shows: the commit in the history, the path everywhere else.
item() {
    line=$(sed -n "$(($1 + 1))p" "$DF_STATE/items")
    key=${line%%"$tab"*}
    rest=${line#*"$tab"}
    path=${rest%%"$tab"*}
    orig=${rest#*"$tab"}
    if [ "$DF_KIND" = commits ]; then id=$key; else id=$path; fi
}

# quotePath off for the same reason as status -z: in diff headers and
# --name-only git would otherwise print the umlaut path as "Gr\303\266...".
g() { git -c core.quotePath=false --no-pager "$@"; }

merges=--diff-merges=first-parent

# --- the lists -------------------------------------------------------------

# A rename comes as two records, the new path and then the old one. Status
# letters are coloured the way git status colours them: the index green, the
# working tree red.
list_worktree() {
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

# The format of git lg. The commit is the first word after the graph; a
# line with none is all graph and gets an empty item. Flushed line by line:
# fzf shows the history while git log is still writing it.
list_commits() {
    git log --graph --color=always --format='%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(dim white)- %an%C(reset)%C(auto)%d%C(reset)' "$@" |
    awk -v items="$DF_STATE/items" '
        BEGIN { printf "" >items }
        {
            print
            s = $0
            gsub(/\033\[[0-9;]*m/, "", s)
            sub(/^[*|\/\\_ .-]*/, "", s)
            sub(/ .*/, "", s)
            if (s !~ /^[0-9a-f]+$/) s = ""
            print s "\t\t" >items
            fflush(items); fflush()
        }
    '
}

# A rename comes as the status with its score, the old path, the new one.
list_files() {
    g show --format= --name-status -z -M "$merges" "$DF_COMMIT" |
    tr '\0' '\n' |
    awk -v items="$DF_STATE/items" '
        BEGIN {
            e = "\033"; off = e "[0m"
            green = e "[32m"; red = e "[31m"; dim = e "[2m"
            printf "" >items
        }
        want == "" { st = substr($0, 1, 1); orig = ""
                     want = st ~ /[RC]/ ? "orig" : "path"; next }
        want == "orig" { orig = $0; want = "path"; next }
        {
            want = ""
            show = st == "A" ? green st off : st == "D" ? red st off : st
            print show "\t" $0 (orig == "" ? "" : dim " <- " orig off)
            print st "\t" $0 "\t" orig >items
        }
    '
}

# Only git df reloads its list: after nvim, which may have changed a file.
cmd_list() { list_worktree; }

# --- the preview -----------------------------------------------------------

# git $2 -- diff or show -- with the arguments after it, in the style $1
# names.
diff_as() {
    style=$1
    sub=$2
    shift 2
    case $style in
        delta)
            g "$sub" --no-ext-diff "$@" |
            delta --paging never --width "$cols" --hunk-label '•' ;;
        difft)
            DFT_COLOR=always DFT_WIDTH=$cols \
            g -c diff.external=difft "$sub" --ext-diff "$@" ;;
        git)
            g "$sub" --no-ext-diff --color=always "$@" ;;
    esac
}

# The same as plain unified diff, which cmd_edit reads line numbers from.
raw() {
    sub=$2
    shift 2
    g "$sub" --no-ext-diff --no-color "$@"
}

heading() { printf '%s[%sm%s%s[0m\n' "$esc" "$1" "$2" "$esc"; }

# The current item in style $1, through $2: diff_as, or raw. In the working
# tree what is staged comes first, then what is not; untracked files and
# conflicts have one part only.
render() {
    case $DF_KIND in
        commits)
            "$2" "$1" show --stat --patch -M "$merges" "$key" ;;
        files)
            if [ -n "$orig" ]; then
                "$2" "$1" show --format= -M "$merges" "$DF_COMMIT" -- "$orig" "$path"
            else
                "$2" "$1" show --format= "$merges" "$DF_COMMIT" -- "$path"
            fi ;;
        worktree)
            render_worktree "$@" ;;
    esac
}

render_worktree() {
    case $key in
        '??')
            [ "$2" = raw ] || heading 31 untracked
            "$2" "$1" diff --no-index -- /dev/null "$path" ;;
        DD|AU|UD|UA|DU|AA|UU)
            [ "$2" = raw ] || heading 35 conflict
            "$2" "$1" diff -- "$path" ;;
        *)
            x=${key%?}
            y=${key#?}
            if [ "$x" != ' ' ]; then
                [ "$2" = raw ] || heading 32 staged
                if [ -n "$orig" ]; then
                    "$2" "$1" diff --cached -M -- "$orig" "$path"
                else
                    "$2" "$1" diff --cached -- "$path"
                fi
            fi
            if [ "$y" != ' ' ]; then
                if [ "$2" != raw ]; then
                    [ "$x" != ' ' ] && echo
                    heading 31 'not staged'
                fi
                "$2" "$1" diff -- "$path"
            fi ;;
    esac
}

cmd_preview() {
    item "$1"
    # A line that is all graph has no commit to show.
    [ -n "$id" ] || return 0
    load
    cols=${FZF_PREVIEW_COLUMNS:-80}
    out=$DF_STATE/render.$$
    { printf '%s\t%s\n' "$mode" "$id"; render "$mode" diff_as 2>&1; } >"$out"
    tail -n +2 "$out"
    mv -f "$out" "$DF_STATE/render"
}

# --- moving in the preview -------------------------------------------------

# The preview lines that start a hunk, counted from 1 like
# change-preview-window(+N). Nothing when the rendering on file is of another
# line or mode: the preview has not caught up yet. difftastic heads each hunk
# with its file's path, so that needs the commit's paths in the history.
markers() {
    if [ "$DF_KIND" = commits ]; then
        paths=$(g show --format= --name-only -M "$merges" "$id")
    else
        paths=$path
    fi
    DF_WANT="$mode$tab$id" DF_PATHS="$paths" awk -v mode="$mode" '
        BEGIN {
            k = split(ENVIRON["DF_PATHS"], p, "\n")
            for (i = 1; i <= k; i++) paths[p[i]]
        }
        NR == 1 { if ($0 != ENVIRON["DF_WANT"]) exit; next }
        { gsub(/\033\[[0-9;:]*[A-Za-z]/, ""); n = NR - 1 }
        mode == "git" && /^@@/ { print n }
        mode == "difft" {
            i = index($0, " --- ")
            if (i > 1 && (substr($0, 1, i - 1) in paths)) print n
        }
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
    marks=$(markers)
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
    k=$hunk
    if [ "$k" -eq 0 ] && [ -f "$DF_STATE/render" ]; then
        k=$(markers | awk -v o="$offset" '$1 <= o' | wc -l)
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

    if [ "$DF_KIND" = worktree ]; then
        if [ ! -f "$path" ]; then
            printf '%s is not in the working tree. enter goes back.\n' "$path"
            read -r _
            return 0
        fi
        exec nvim "+$line" -- "$path"
    fi

    # The file as the commit has it -- before it, for a deletion -- in a
    # buffer named after both that cannot be written. The name goes through
    # the environment, so fnameescape deals with spaces in it, not sh.
    short=$(git rev-parse --short "$DF_COMMIT")
    if [ "$key" = D ]; then rev=$DF_COMMIT^ name="$short^:$path"
    else rev=$DF_COMMIT name="$short:$path"; fi
    g show "$rev:$path" |
    DF_NAME=$name nvim -R \
        -c 'exe "file " . fnameescape($DF_NAME)' \
        -c 'setlocal buftype=nofile bufhidden=wipe noswapfile' \
        -c 'filetype detect' "+$line" -
}

# --- the files of a commit -------------------------------------------------
# A second fzf, run by the history's enter. When it ends, the history is
# back where it was; after ctrl-c it ends too, through `back`.

cmd_files() {
    item "$1"
    [ -n "$key" ] || return 0
    load
    DF_PARENT=$DF_STATE
    DF_STATE=$(mktemp -d) || { err "cannot create a temporary directory"; return 1; }
    DF_KIND=files
    DF_COMMIT=$key
    export DF_PARENT DF_STATE DF_KIND DF_COMMIT
    trap 'rm -rf -- "$DF_STATE"' EXIT
    # The files open in the mode the history was in.
    save "$mode" 1 0
    pick_files 'esc back · ctrl-c quit'
    return 0
}

cmd_back() { [ -f "$DF_STATE/quit" ] && echo abort; return 0; }

# The fzf of $DF_COMMIT's files; $1 ends the header: what esc does there.
pick_files() {
    title=$(git log -1 --format='%h %s' "$DF_COMMIT")
    list_files | pick "$title
enter nvim, read-only · alt-d/t/g delta/difft/git · alt-n/p next/previous hunk
ctrl-d/u half page · ctrl-f/b page · shift-down/up line · $1" \
        --nth 2.. \
        --bind 'enter:execute("$DF_SELF" edit {n})' \
        --bind 'ctrl-c:execute-silent(touch "$DF_PARENT/quit")+abort'
}

# --- main ------------------------------------------------------------------

# fzf on stdin, with the preview and the keys every list shares; $1 is the
# header, the rest are the options of this list. --no-height and the preview
# window override FZF_DEFAULT_OPTS, which asks for 40% of the screen and the
# preview on the right.
pick() {
    header=$1
    shift
    load
    fzf --ansi --no-height --with-shell 'sh -c' \
        --delimiter "$tab" --tabstop 3 \
        --header "$header" \
        --preview '"$DF_SELF" preview {n}' \
        --preview-window 'up,70%' --preview-label " $mode " \
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
        "$@"
}

keys="alt-d/t/g delta/difft/git · alt-n/p next/previous hunk
ctrl-d/u half page · ctrl-f/b page · shift-down/up line · esc quit"

# What both entry points need before the first fzf. The aliases run at the
# top of the work tree already; a direct run may not.
setup() {
    # Resolved before any cd, so a relative $0 still finds this file.
    DF_SELF=$(readlink -f -- "$0") || { err "cannot resolve $0"; exit 1; }
    top=$(git rev-parse --show-toplevel) || exit 1
    DF_STATE=$(mktemp -d) || { err "cannot create a temporary directory"; exit 1; }
    DF_KIND=$1
    export DF_SELF DF_STATE DF_KIND
    trap 'rm -rf -- "$DF_STATE"' EXIT
    trap 'exit 130' INT TERM HUP
    save delta 1 0
}

# 130 is esc, the way out; enter never accepts.
finish() {
    case $1 in 0|1|130) exit 0 ;; esac
    exit "$1"
}

main_worktree() {
    setup worktree
    cd "$top" || exit 1
    list_worktree >"$DF_STATE/list"
    if [ ! -s "$DF_STATE/list" ]; then
        echo "nothing to diff: the working tree is clean"
        exit 0
    fi
    pick "enter nvim · $keys" \
        --nth 2.. \
        --bind 'enter:execute("$DF_SELF" edit {n})+reload("$DF_SELF" list)' \
        <"$DF_STATE/list"
    finish $?
}

main_show() {
    setup commits
    # Options are read where the alias was run from -- GIT_PREFIX, below
    # the top -- so `git sh -- file` means the file in that directory. The
    # check up front is for an unknown revision or a history without
    # commits, whose message fzf would cover.
    cd "${GIT_PREFIX:-.}" || exit 1
    git log -1 --format=%h "$@" >/dev/null || exit 1
    list_commits "$@" |
    (
        cd "$top" || exit 1
        pick "enter files · $keys" \
            --no-sort \
            --bind 'enter:execute("$DF_SELF" files {n})+transform("$DF_SELF" back)'
    )
    finish $?
}

# One commit, the way git show takes it: a hash, HEAD, a branch or tag,
# HEAD~2 -- whatever rev-parse turns into a single commit. A range, an option
# or a path is left to git log.
is_commit() {
    case $1 in
        ''|-*) return 1 ;;
    esac
    git rev-parse --verify --quiet "$1^{commit}" >/dev/null
}

# git sh <commit>: the commit's files, with no history before them. ctrl-c
# leaves its note for the history in this list's own directory, where
# nothing reads it.
main_commit() {
    setup files
    DF_COMMIT=$(git rev-parse --verify --quiet "$1^{commit}") || exit 1
    DF_PARENT=$DF_STATE
    export DF_COMMIT DF_PARENT
    cd "$top" || exit 1
    pick_files 'esc quit'
    finish $?
}

# --- dispatch --------------------------------------------------------------
# Everything but the entry points is called by fzf, with $DF_STATE set.

case ${1-} in
    '')        main_worktree ;;
    show)      shift
               if [ $# -eq 1 ] && is_commit "$1"; then main_commit "$1"
               else main_show "$@"; fi ;;
    -h|--help) usage ;;
    list|preview|scroll|hunk|focus|mode|edit|files|back)
        if [ -z "${DF_STATE-}" ]; then
            err "$1 is called by fzf -- run git df or git sh"
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
