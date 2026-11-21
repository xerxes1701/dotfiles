#!/bin/sh
# The remote-tracking branches, newest commit first, the way git-brl.sh
# lists the local ones. `git brlr` in .gitconfig; options go to
# `git branch -r --list`, so a pattern narrows the list: `git brlr 'origin/impl*'`.
#
#   *            the current branch is its local branch
#   ↑2 ↓5  =     the local branch is ahead of and behind it, or level with it
#   none         no local branch: none tracks it and none has its name
#   merged       nothing on it that the main branch (git main-branch) lacks,
#                so deleting it loses nothing; the name is dimmed.
#   ← name       its local branch, when that has a different name
#
# The local branch is the one whose upstream it is, or else the one with
# the same name (a branch pushed without -u has no upstream). Comparing
# with it costs one git rev-list per branch that has one.
#
# Run `git fetch --prune` first: the list shows what the last fetch saw.

set -u

git rev-parse --git-dir >/dev/null || exit 1

# The main branch, as in git-brl.sh.
main=$(git main-branch 2>/dev/null)
if [ -z "$main" ]; then
    for b in main master; do
        if git show-ref --verify --quiet "refs/heads/$b"; then
            main=$b
            break
        fi
    done
fi

if [ -t 1 ]; then tty=true; else tty=false; fi
color=$(git config --get-colorbool color.branch "$tty")

# Tab-separated (%09): ref names cannot contain a tab. The local branches
# come first (L), so that each remote one (R) can look up its local branch.
lfmt='L%09%(HEAD)%09%(refname)%09%(upstream)'
rfmt='R%09%(committerdate:short)%09%(refname:short)%09%(refname)%09%(refname:lstrip=3)%09%(symref)'
[ -n "$main" ] && rfmt="$rfmt%09%(ahead-behind:$main)"

{
    git for-each-ref --format="$lfmt" refs/heads
    git branch -r --list --sort=-committerdate --format="$rfmt" "$@"
} |
awk -F '\t' -v color="$color" -v trunk="$main" '
    BEGIN {
        if (color == "true") {
            e = "\033["; off = e "m"
            bgreen = e "1;32m"; green = e "32m"; red = e "31m"
            yellow = e "33m"; dim = e "2m"
        }
    }

    function cell(c, text, width,   t, pad) {
        t = text
        gsub(/↑|↓/, "x", t)
        pad = width - length(t)
        while (pad-- > 0) text = text " "
        return c text off
    }

    # A word for sh -c: ref names may hold quotes and dollar signs.
    function q(s) { gsub(/\047/, "\047\\\047\047", s); return "\047" s "\047" }

    $1 == "L" {
        islocal[$3] = 1
        if ($4 != "") tracker[$4] = $3
        if ($2 == "*") current = $3
        next
    }

    $1 == "R" {
        date = $2; name = $3; full = $4; br = $5; sym = $6; ab = $7
        if (sym != "") next                     # origin/HEAD -> origin/main

        loc = ""
        if (full in tracker) loc = tracker[full]
        else if (("refs/heads/" br) in islocal) loc = "refs/heads/" br

        if (loc == "") { rcol = dim; rel = "none" }
        else {
            cmd = "git rev-list --left-right --count " q(loc "..." full)
            cmd | getline counts
            close(cmd)
            split(counts, c, " ")
            rcol = ""; rel = ""
            if (c[1] > 0) rel = "↑" c[1]
            if (c[2] > 0) rel = rel (rel != "" ? " " : "") "↓" c[2]
            if (rel == "") rel = "="
        }

        split(ab, n, " ")
        merged = ab != "" && n[1] == 0 && name != trunk
        ncol = merged ? dim : red

        if (loc != "" && loc == current) mark = bgreen "* " off
        else mark = "  "

        lname = loc
        sub(/^refs\/heads\//, "", lname)
        other = (loc != "" && lname != br) ? dim " ← " lname off : ""

        printf "%s%s %s %s %s%s\n", mark, yellow date off,
            cell(rcol, rel, 9), cell(green, merged ? "merged" : "", 6),
            ncol name off, other
    }
'
