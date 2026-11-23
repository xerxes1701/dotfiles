#!/bin/sh
# Changes in fzf, with the diff of the current line in the preview. Behind
# al's `git review` (al/.config/al/aliases/git.toml; g re, g re sho, g re a):
#
#   git review       the working tree: one line per changed file -- staged,
#                    not staged and untracked, not the ignored ones.
#   git review show  the history, drawn as git lg draws it. Enter on a commit
#                    lists its files in a second fzf; esc there goes back to
#                    the history, where it was, and ctrl-c ends both. Given
#                    one commit and nothing else -- a hash, HEAD, a branch,
#                    HEAD~2 -- it lists that commit's files straight away,
#                    and esc quits.
#   git review add   the list of git review, to stage from: alt-a stages the
#                    marked files, alt-u unstages them. Enter lists the
#                    file's hunks in a second fzf, where enter stages the
#                    marked hunks, alt-s turns to the staged ones to unstage
#                    them, and alt-e stages a hunk edited in nvim first, like
#                    e in git add -p. esc goes back to the files. An
#                    untracked file is added intent-to-add while its hunks
#                    are listed, and taken back out if nothing was staged.
#
# Every list has the same preview: delta to begin with, difftastic or git's
# own diff on a key, hunk jumps and scrolling. Enter on a file opens it in
# nvim at the hunk on screen -- in git review the file itself, in git review
# show the file as that commit has it, read-only. fzf steps aside while nvim runs and
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
# POSIX sh, like the other scripts here. On Windows it runs in Git for
# Windows' sh, with the native fzf.exe, delta and difft; fzf starts its
# commands with `sh -c` there as well. Enter opens vim where there is no
# nvim: Git for Windows has one of its own.

set -u

self=${0##*/}
tab=$(printf '\t')
esc=$(printf '\033')

err() { printf '%s: %s\n' "$self" "$*" >&2; }

usage() {
    cat <<EOF
usage: git review                    the working tree's changes
       git review add                the same, to stage files and hunks
       git review show [log options] the history, then a commit's files
       git review show <commit>      that commit's files
       $self [show [<commit> | log options]]

  enter               git review: open the file in nvim (or vim, where there
                      is no nvim) at the hunk on screen
                      git review add: the file's hunks; there, stage the marked
                      hunks (unstage, on the staged side)
  tab                 git review add: mark a file or hunk
  alt-a alt-u         git review add: stage / unstage the marked files
  alt-s               git review add, in the hunks: the staged / not staged side
  alt-e               git review add, in the hunks: edit the hunk, then stage it
  ctrl-o              git review add: open the file in nvim at the hunk on screen
                      git review show: the commit's files; there, open the file as
                      the commit has it, read-only
  alt-d alt-t alt-g   the preview in delta, difftastic, git diff
  alt-n alt-p         next / previous hunk
  ctrl-d ctrl-u       half a page down / up
  ctrl-f ctrl-b       a page down / up
  shift-down/up       a line down / up
  esc                 quit; in a commit's files, back to the history
  ctrl-c              quit, from the files as well

git review show hands its options to git log: \`git review show -- src/\`,
\`git review show main..\`. one commit alone -- \`git review show HEAD\`, a hash,
a branch, HEAD~2 -- opens its files, where esc quits; \`git review show main --\`
is the history from it.
the mouse wheel scrolls too, but hunk jumps do not see where it went.
EOF
}

# --- state -----------------------------------------------------------------
# Every fzf has a directory of its own, $DF_STATE, which everything it starts
# inherits, together with:
#   DF_KIND    worktree (git review), commits or files (git review show)
#   DF_COMMIT  for files: the commit
#   DF_PARENT  for files: the history's directory
#   DF_PATH, DF_ORIG, DF_SIDE  for hunks: the file, the path it was
#              renamed from, the side listed first
# In the directory:
#   items    one line per list line: the status (in the history: the
#            commit, or nothing on a line that is all graph), the path, the
#            path before a rename
#   state    the preview's mode, its top line, the hunk last jumped to (0:
#            none since the last scroll)
#   render   the preview as last rendered, after a key line: mode, id
#   quit     in the history's or the file list's directory: ctrl-c was
#            pressed in the files or the hunks
#   side     for hunks: staged or unstaged, the side listed
#   head, hunk.N  for hunks: the diff's header lines, and each hunk

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
    case $DF_KIND in
        commits) id=$key ;;
        hunks)   id="$path#$key" ;;
        *)       id=$path ;;
    esac
}

# quotePath off for the same reason as status -z: in diff headers and
# --name-only git would otherwise print the umlaut path as "Gr\303\266...".
# safecrlf off: with autocrlf, as on Windows, git warns about every file
# with LF endings, and the preview shows stderr.
g() { git -c core.quotePath=false -c core.safecrlf=false --no-pager "$@"; }

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

# The hunks of $DF_PATH on the side in $DF_STATE/side, split into the
# header lines and one file per hunk, for git apply to put back together.
# The list shows each hunk's @@ line and how many lines it adds and removes.
list_hunks() {
    read -r side <"$DF_STATE/side"
    rm -f -- "$DF_STATE"/hunk.*
    # A staged rename would come as a new file, and unstaging its hunks
    # would undo only half of it.
    if [ "$side" = staged ] && [ -n "$DF_ORIG" ]; then : >"$DF_STATE/items"; return 0; fi
    if [ "$side" = staged ]; then set -- --cached; else set --; fi
    g diff --no-color --no-ext-diff "$@" -- "$DF_PATH" |
    awk -v d="$DF_STATE" -v items="$DF_STATE/items" -v path="$DF_PATH" '
        BEGIN {
            e = "\033"; off = e "[0m"
            cyan = e "[36m"; green = e "[32m"; red = e "[31m"
            printf "" >items; head = d "/head"; printf "" >head
        }
        function emit() {
            if (!n) return
            close(f)
            print n "\t" cyan h off "\t" green "+" a off " " red "-" r off
            print n "\t" path "\t" >items
        }
        /^@@/ { emit(); n++; f = d "/hunk." n; h = $0; a = r = 0
                print >f; next }
        n == 0 { print >head; next }
        { print >f; c = substr($0, 1, 1); if (c == "+") a++; else if (c == "-") r++ }
        END { emit() }
    '
}

# git review and git review add reload their list after nvim, which may have changed a
# file, and git review add after staging; the hunks after every change too.
cmd_list() {
    if [ "$DF_KIND" = hunks ]; then list_hunks; else list_worktree; fi
}

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
        hunks)
            render_hunk "$@" ;;
    esac
}

# One hunk: in delta and as git colours it, as a patch; in difftastic, the
# lines before against the lines after, since it does not read patches.
render_hunk() {
    if [ "$2" = raw ]; then
        cat -- "$DF_STATE/head" "$DF_STATE/hunk.$key"
        return
    fi
    case $1 in
        delta)
            cat -- "$DF_STATE/head" "$DF_STATE/hunk.$key" |
            delta --paging never --width "$cols" --hunk-label '•' ;;
        git)
            cat -- "$DF_STATE/head" "$DF_STATE/hunk.$key" |
            awk -v e="$esc" '
                FNR == 1 && !body && /^diff/ { hd = 1 }
                /^@@/ { hd = 0; body = 1; print e "[36m" $0 e "[0m"; next }
                hd { print e "[1m" $0 e "[0m"; next }
                /^\+/ { print e "[32m" $0 e "[0m"; next }
                /^-/ { print e "[31m" $0 e "[0m"; next }
                { print }
            ' ;;
        difft)
            b=$DF_STATE/before.$$
            a=$DF_STATE/after.$$
            ext=${path##*/}
            case $ext in *.*) ext=.${ext##*.} ;; *) ext= ;; esac
            awk -v b="$b$ext" -v a="$a$ext" '
                NR == 1 { next }
                /^ / { print substr($0, 2) >b; print substr($0, 2) >a }
                /^-/ { print substr($0, 2) >b }
                /^\+/ { print substr($0, 2) >a }
            ' "$DF_STATE/hunk.$key"
            touch -- "$b$ext" "$a$ext"
            difft --color always --width "$cols" --display side-by-side-show-both \
                "$b$ext" "$a$ext" | tail -n +2
            rm -f -- "$b$ext" "$a$ext" ;;
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

    if [ "$DF_KIND" = worktree ] || [ "$DF_KIND" = hunks ]; then
        if [ ! -f "$path" ]; then
            printf '%s is not in the working tree. enter goes back.\n' "$path"
            read -r _
            return 0
        fi
        exec "$DF_EDITOR" "+$line" -- "$path"
    fi

    # The file as the commit has it -- before it, for a deletion -- in a
    # buffer named after both that cannot be written. The name goes through
    # the environment, so fnameescape deals with spaces in it, not sh.
    short=$(git rev-parse --short "$DF_COMMIT")
    if [ "$key" = D ]; then rev=$DF_COMMIT^ name="$short^:$path"
    else rev=$DF_COMMIT name="$short:$path"; fi
    g show "$rev:$path" |
    DF_NAME=$name "$DF_EDITOR" -R \
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
enter $DF_EDITOR, read-only · alt-d/t/g delta/difft/git · alt-n/p next/previous hunk
ctrl-d/u half page · ctrl-f/b page · shift-down/up line · $1" \
        --nth 2.. \
        --bind 'enter:execute("$DF_SELF" edit {n})' \
        --bind 'ctrl-c:execute-silent(touch "$DF_PARENT/quit")+abort'
}

# --- staging ---------------------------------------------------------------
# git review add. Every command here answers fzf's transform: the list again, and
# git's complaint in the footer when there is one.

# What to do after a change: $1 is git's exit status, $2 the file with its
# messages.
answer() {
    if [ "$1" -eq 0 ]; then
        echo 'deselect-all+reload("$DF_SELF" list)+change-footer:'
    else
        printf 'deselect-all+reload("$DF_SELF" list)+change-footer:%s\n' \
            "$(tr '\n' ' ' <"$2" | tr -d '()')"
    fi
}

# The marked files ($2 on, as {+n}): $1 add stages them, deletions too;
# $1 reset unstages them, a rename with the path it came from.
cmd_stage() {
    how=$1
    shift
    log=$DF_STATE/err
    : >"$log"
    st=0
    for n in "$@"; do
        item "$n"
        if [ "$how" = add ]; then
            git add -A -- "$path" 2>>"$log" || st=$?
        elif [ -n "$orig" ]; then
            git restore --staged -- "$path" "$orig" 2>>"$log" || st=$?
        else
            git restore --staged -- "$path" 2>>"$log" || st=$?
        fi
    done
    answer "$st" "$log"
}

# The hunks of a file, in an fzf of their own, like the files of a commit.
cmd_hunks() {
    item "$1"
    case $key in
        DD|AU|UD|UA|DU|AA|UU)
            printf '%s has a conflict: resolve it, then stage it whole. enter goes back.\n' "$path"
            read -r _
            return 0 ;;
    esac
    # Untracked: in the index with nothing in it, so git diff has hunks.
    added=
    if [ "$key" = '??' ]; then
        git add -N -- "$path" || return 0
        added=1
    fi
    DF_PARENT=$DF_STATE
    DF_STATE=$(mktemp -d) || { err "cannot create a temporary directory"; return 1; }
    DF_KIND=hunks
    DF_PATH=$path
    DF_ORIG=$orig
    export DF_PARENT DF_STATE DF_KIND DF_PATH DF_ORIG
    trap 'rm -rf -- "$DF_STATE"' EXIT
    # The hunks open in the mode the files were in.
    read -r mode _ <"$DF_PARENT/state"
    save "$mode" 1 0
    # The side with something to stage first, else the staged one.
    if [ "${key#?}" != ' ' ]; then echo unstaged; else echo staged; fi >"$DF_STATE/side"
    list_hunks >"$DF_STATE/list"
    if [ ! -s "$DF_STATE/list" ] && [ "$key" != '??' ] && [ "${key%?}" != ' ' ] &&
        [ "${key#?}" != ' ' ]; then
        echo staged >"$DF_STATE/side"
        list_hunks >"$DF_STATE/list"
    fi
    if [ ! -s "$DF_STATE/list" ]; then
        printf '%s has no hunks -- binary, or only its mode or name changed: alt-a/alt-u stage it whole. enter goes back.\n' "$path"
        read -r _
    else
        pick "$(hunks_header)" \
            --multi --nth 2.. \
            --footer '' \
            --bind 'enter:transform:"$DF_SELF" apply {+n}' \
            --bind 'alt-e:execute("$DF_SELF" hunkedit {n})+transform:"$DF_SELF" applied' \
            --bind 'alt-s:transform:"$DF_SELF" side' \
            --bind 'ctrl-o:execute("$DF_SELF" edit {n})+deselect-all+reload("$DF_SELF" list)' \
            --bind 'ctrl-c:execute-silent(touch "$DF_PARENT/quit")+abort' \
            <"$DF_STATE/list"
    fi
    # An untracked file nothing was staged of goes back to untracked.
    if [ -n "$added" ] && git diff --cached --quiet -- "$path"; then
        git rm --cached -q -- "$path"
    fi
    return 0
}

hunks_header() {
    read -r side <"$DF_STATE/side"
    if [ "$side" = staged ]; then
        what='staged' do='unstage' other='not staged'
    else
        what='not staged' do='stage' other='staged'
    fi
    printf '%s · %s\nenter %s marked · alt-e edit, then %s · alt-s %s · ctrl-o %s · %s\n%s' \
        "$DF_PATH" "$what" "$do" "$do" "$other" "$DF_EDITOR" \
        'tab mark' "$keys_back"
}

# The marked hunks, through git apply: to the index, or out of it on the
# staged side. --recount, as the hunks of an edit may not add up.
cmd_apply() {
    # An empty side: nothing to apply.
    [ $# -gt 0 ] && [ -s "$DF_STATE/items" ] || return 0
    log=$DF_STATE/err
    p=$DF_STATE/patch
    cat -- "$DF_STATE/head" >"$p"
    for n in "$@"; do
        item "$n"
        cat -- "$DF_STATE/hunk.$key" >>"$p"
    done
    read -r side <"$DF_STATE/side"
    if [ "$side" = staged ]; then rev=-R; else rev=; fi
    g apply --cached --recount $rev -- "$p" 2>"$log"
    st=$?
    after_apply "$st"
}

# After a change: back to the files once the side is empty, else the list
# again.
after_apply() {
    list_hunks >"$DF_STATE/next"
    if [ "$1" -eq 0 ] && [ ! -s "$DF_STATE/next" ]; then
        echo abort
    else
        answer "$1" "$DF_STATE/err"
    fi
}

# alt-e: the hunk in nvim, as git add -p's e has it; staged as it is when
# nvim quits, and not at all when it is left empty. The result is left for
# cmd_applied, which fzf runs next, so the answer is a transform.
cmd_hunkedit() {
    item "$1"
    e=$DF_STATE/edit.patch
    {
        cat -- "$DF_STATE/hunk.$key"
        echo '# ---'
        echo '# Remove a - line to keep it, a + line to leave it out; lines'
        echo '# starting with # are dropped. Empty: nothing is staged.'
    } >"$e"
    "$DF_EDITOR" -- "$e"
    p=$DF_STATE/patch
    log=$DF_STATE/err
    if ! grep -qv '^#' "$e"; then
        echo 0 >"$DF_STATE/edited"
        : >"$log"
        return 0
    fi
    { cat -- "$DF_STATE/head"; grep -v '^#' "$e"; } >"$p"
    read -r side <"$DF_STATE/side"
    if [ "$side" = staged ]; then rev=-R; else rev=; fi
    g apply --cached --recount $rev -- "$p" 2>"$log"
    echo $? >"$DF_STATE/edited"
}

cmd_applied() {
    st=0
    [ -f "$DF_STATE/edited" ] && read -r st <"$DF_STATE/edited"
    rm -f -- "$DF_STATE/edited"
    after_apply "$st"
}

# alt-s: the other side, unless a rename is staged, whose hunks would undo
# only half of it.
cmd_side() {
    read -r side <"$DF_STATE/side"
    if [ "$side" = unstaged ] && [ -n "$DF_ORIG" ]; then
        echo 'change-footer:a staged rename: unstage it whole, with alt-u in the files'
        return 0
    fi
    if [ "$side" = staged ]; then echo unstaged; else echo staged; fi >"$DF_STATE/side"
    echo 'deselect-all+reload("$DF_SELF" list)+transform-header("$DF_SELF" header)+change-footer:'
}

cmd_header() { hunks_header; }

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
keys_back="alt-d/t/g delta/difft/git · alt-n/p next/previous hunk
ctrl-d/u half page · ctrl-f/b page · shift-down/up line · esc back · ctrl-c quit"

# What both entry points need before the first fzf. The aliases run at the
# top of the work tree already; a direct run may not.
setup() {
    # Resolved before any cd, so a relative $0 still finds this file.
    DF_SELF=$(readlink -f -- "$0") || { err "cannot resolve $0"; exit 1; }
    top=$(git rev-parse --show-toplevel) || exit 1
    DF_STATE=$(mktemp -d) || { err "cannot create a temporary directory"; exit 1; }
    DF_KIND=$1
    DF_EDITOR=nvim
    command -v nvim >/dev/null 2>&1 || DF_EDITOR=vim
    export DF_SELF DF_STATE DF_KIND DF_EDITOR
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
    pick "enter $DF_EDITOR · $keys" \
        --nth 2.. \
        --bind 'enter:execute("$DF_SELF" edit {n})+reload("$DF_SELF" list)' \
        <"$DF_STATE/list"
    finish $?
}

main_add() {
    setup worktree
    cd "$top" || exit 1
    list_worktree >"$DF_STATE/list"
    if [ ! -s "$DF_STATE/list" ]; then
        echo "nothing to stage: the working tree is clean"
        exit 0
    fi
    pick "enter hunks · alt-a stage · alt-u unstage · tab mark · ctrl-o $DF_EDITOR
$keys" \
        --multi --nth 2.. \
        --footer '' \
        --bind 'enter:execute("$DF_SELF" hunks {n})+deselect-all+reload("$DF_SELF" list)+transform("$DF_SELF" back)' \
        --bind 'alt-a:transform:"$DF_SELF" stage add {+n}' \
        --bind 'alt-u:transform:"$DF_SELF" stage reset {+n}' \
        --bind 'ctrl-o:execute("$DF_SELF" edit {n})+reload("$DF_SELF" list)' \
        <"$DF_STATE/list"
    finish $?
}

main_show() {
    setup commits
    # Options are read where the alias was run from -- GIT_PREFIX, below
    # the top -- so `git review show -- file` means the file in that directory. The
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

# git review show <commit>: the commit's files, with no history before them. ctrl-c
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
    add)       main_add ;;
    show)      shift
               if [ $# -eq 1 ] && is_commit "$1"; then main_commit "$1"
               else main_show "$@"; fi ;;
    -h|--help) usage ;;
    list|preview|scroll|hunk|focus|mode|edit|files|back|stage|hunks|apply|hunkedit|applied|side|header)
        if [ -z "${DF_STATE-}" ]; then
            err "$1 is called by fzf -- run git review or git review show"
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
