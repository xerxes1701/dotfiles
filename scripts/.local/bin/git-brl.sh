#!/bin/sh
# The local branches, newest commit first, with what is left to do on each.
# `git brl` in .gitconfig; options go to `git branch --list`, so a pattern
# narrows the list: `git brl 'MiGa*'`.
#
#   * +          the current branch, one checked out in another worktree
#   ↑2 ↓5  =     ahead of and behind its upstream, or level with it
#   local        no upstream
#   gone         the upstream was deleted on the remote, usually after its
#                merge request went in. The branch may still have commits
#                the main branch lacks -- rebased before the merge, or
#                abandoned -- so look before deleting it.
#   merged       nothing on it that the main branch (git main-branch) lacks,
#                so deleting it loses nothing; the name is dimmed. A branch
#                with no commits of its own yet counts as well.
#
# Two measured details are why this is a script and not a --format alias:
#
#   merged     %(ahead-behind:origin/master) gives "0 1619" for a merged
#              branch, but git's format can only test whether a field is
#              empty, not whether it starts with 0. awk can.
#   squashes   a squash or rebase merge is not detected. Comparing patches
#              with git cherry took 2.5 s for a single FirstX branch and
#              found 1 of its 14 patches, which settles nothing; `gone`
#              covers those branches instead.
#
# In a FirstX worktree whose git directory is on the Windows drive, the
# extra fields double the time of the plain list (1.9 s to ~3.8 s); that is
# the 9p filesystem, which every object read crosses.

set -u

# One message and a failure outside a repository, rather than one from
# each git call below and the exit status of awk.
git rev-parse --git-dir >/dev/null || exit 1

# The main branch: origin's, or else a local main or master. Without one
# there is nothing to call merged, and that column stays empty.
main=$(git main-branch 2>/dev/null)
if [ -z "$main" ]; then
    for b in main master; do
        if git show-ref --verify --quiet "refs/heads/$b"; then
            main=$b
            break
        fi
    done
fi

# Colours the way git branch decides them: color.branch, and only for a
# terminal unless that says always.
if [ -t 1 ]; then tty=true; else tty=false; fi
color=$(git config --get-colorbool color.branch "$tty")

# Tab-separated (%09): ref names cannot contain a tab.
fmt='%(HEAD)%09%(worktreepath)%09%(committerdate:short)%09%(refname:short)%09%(upstream)%09%(upstream:track,nobracket)'
[ -n "$main" ] && fmt="$fmt%09%(ahead-behind:$main)"

# --list, so that a pattern filters instead of creating a branch.
git branch --list --sort=-committerdate --format="$fmt" "$@" |
awk -F '\t' -v color="$color" -v trunk="${main#origin/}" '
    BEGIN {
        if (color == "true") {
            e = "\033["; off = e "m"
            bgreen = e "1;32m"; green = e "32m"; magenta = e "35m"
            cyan = e "36m"; yellow = e "33m"; red = e "31m"; dim = e "2m"
        }
    }

    # $2 padded to $3 columns, then wrapped in colour $1. The arrows are
    # three bytes in an awk that counts bytes, one column on screen.
    function cell(c, text, width,   t, pad) {
        t = text
        gsub(/↑|↓/, "x", t)
        pad = width - length(t)
        while (pad-- > 0) text = text " "
        return c text off
    }

    {
        head = $1; wt = $2; date = $3; name = $4
        up = $5; track = $6; ab = $7

        if (head == "*")  { mark = bgreen "* " off; ncol = bgreen }
        else if (wt != "") { mark = magenta "+ " off; ncol = magenta }
        else               { mark = "  "; ncol = cyan }

        if (up == "")            { rcol = dim; remote = "local" }
        else if (track == "gone") { rcol = red; remote = "gone" }
        else if (track == "")    { rcol = ""; remote = "=" }
        else {
            rcol = ""; remote = ""
            if (match(track, /ahead [0-9]+/))
                remote = "↑" substr(track, RSTART + 6, RLENGTH - 6)
            if (match(track, /behind [0-9]+/)) {
                if (remote != "") remote = remote " "
                remote = remote "↓" substr(track, RSTART + 7, RLENGTH - 7)
            }
        }

        split(ab, n, " ")
        merged = ab != "" && n[1] == 0 && name != trunk
        if (merged && ncol == cyan) ncol = dim

        printf "%s%s %s %s %s\n", mark, yellow date off,
            cell(rcol, remote, 9), cell(green, merged ? "merged" : "", 6),
            ncol name off
    }
'
