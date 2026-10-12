#!/bin/sh
# Pick a local branch with fzf and go to it -- the WSL side of `gsw` in the
# Windows PowerShell profile.
#
# If the branch is checked out in a worktree, its path is printed and the `gsw`
# shell function (fish, nushell, zsh) changes into it; git would refuse to
# switch to it here anyway. Otherwise the branch is switched to in place and
# nothing is printed. stdout is reserved for that path, so git's own output is
# sent to stderr.
#
# Worktree paths recorded by Windows git are translated as in gz.sh.

set -u

self=${0##*/}

err() { printf '%s: %s\n' "$self" "$*" >&2; }

case ${1:-} in
    -h|--help)
        cat <<EOF
usage: $self

lists the local branches in fzf, with the commits each has on top of
origin/master as preview. a branch checked out in a worktree prints that
worktree's path; any other is switched to with \`git switch\`. meant to be
called through the \`gsw\` shell function, which changes into a printed path.
EOF
        exit 0
        ;;
esac

git rev-parse --git-dir >/dev/null 2>&1 || { err "not in a git repository"; exit 1; }
command -v fzf >/dev/null 2>&1 || { err "fzf is not on PATH"; exit 1; }

branch=$(git branch --format '%(refname:short)' | sort |
    fzf --with-shell='sh -c' --preview 'git lg --oneline origin/master..{} --color=always')
[ -n "$branch" ] || exit 0

worktree=$(git worktree list --porcelain | awk -v want="branch refs/heads/$branch" '
    /^worktree / { p = substr($0, 10) }
    $0 == want   { print p; exit }')

if [ -n "$worktree" ]; then
    case $worktree in
        */[A-Za-z]:/*)
            win=$(printf '%s' "$worktree" | sed 's#^.*/\([A-Za-z]:/\)#\1#')
            worktree=$(wslpath -u "$win" 2>/dev/null) || {
                err "cannot translate the worktree path: $win"
                exit 1
            }
            ;;
    esac
    if [ ! -d "$worktree" ]; then
        err "$branch is checked out in $worktree, which does not exist"
        exit 1
    fi
    printf '%s\n' "$worktree"
    exit 0
fi

git switch "$branch" >&2
