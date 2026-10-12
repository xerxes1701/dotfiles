#!/bin/sh
# Pick a worktree of the FirstX repository with fzf and print its path -- the
# WSL side of `gz` in the Windows PowerShell profile.
#
# A script cannot change its parent's directory, so this only prints the
# choice; `gz` in fish, nushell and zsh is a function around it that does the
# `cd`. Nothing is printed when the pick is cancelled, and the exit status is
# still 0, so the wrappers need no special case for it.
#
# The worktree list is the whole repository's, including the worktrees created
# by Windows git. Those record their paths Windows-style, which WSL git then
# prints glued onto the gitdir, e.g.
#
#   /mnt/c/SWProjekte/firstx_/.git/worktrees/firstx-b/C:/SWProjekte/firstx-b
#
# so the part from the drive letter on is taken and handed to wslpath. The
# preview shows the log by commit id through the repository itself, because
# WSL git cannot operate inside such a worktree at all.
#
# With a search text the first fzf match is taken without asking, as
# `gz <text>` does on Windows.

set -u

self=${0##*/}

err() { printf '%s: %s\n' "$self" "$*" >&2; }

usage() {
    cat <<EOF
usage: $self [search text]

lists the worktrees of \$GZ_REPO (default: ~/SWProjekte/firstx-wa) in fzf and
prints the chosen one's path. with a search text the best match is printed
without asking. meant to be called through the \`gz\` shell function, which
changes into the printed directory.
EOF
}

case ${1:-} in
    -h|--help) usage; exit 0 ;;
esac

repo=${GZ_REPO:-$HOME/SWProjekte/firstx-wa}
if ! git -C "$repo" rev-parse --git-dir >/dev/null 2>&1; then
    err "not a git repository: $repo (set GZ_REPO)"
    exit 1
fi
command -v fzf >/dev/null 2>&1 || { err "fzf is not on PATH"; exit 1; }

# One worktree per line: path, branch, commit -- tab-separated.
worktrees=$(
    git -C "$repo" worktree list --porcelain | awk -v OFS='\t' '
        function flush() { if (p != "") print p, b, h }
        /^worktree / { flush(); p = substr($0, 10); b = "(detached)"; h = "" }
        /^HEAD /     { h = substr($0, 6, 11) }
        /^branch /   { b = substr($0, 8); sub(/^refs\/heads\//, "", b) }
        END          { flush() }' |
    while IFS='	' read -r path branch head; do
        case $path in
            */[A-Za-z]:/*)
                win=$(printf '%s' "$path" | sed 's#^.*/\([A-Za-z]:/\)#\1#')
                path=$(wslpath -u "$win" 2>/dev/null) || continue
                ;;
        esac
        # A worktree whose directory is gone cannot be changed into.
        [ -d "$path" ] || continue
        printf '%s\t%s\t%s\n' "$path" "$branch" "$head"
    done
)

if [ -z "$worktrees" ]; then
    err "no worktrees found in $repo"
    exit 1
fi

if [ $# -gt 0 ]; then
    match=$(printf '%s\n' "$worktrees" | fzf -f "$*" | head -n 1)
else
    # The preview runs in whatever $SHELL is; --with-shell pins it to sh so the
    # quoting below holds under fish and nushell as well.
    export GZ_REPO_RESOLVED="$repo"
    match=$(printf '%s\n' "$worktrees" |
        fzf --delimiter='\t' --with-nth=1,2 --with-shell='sh -c' \
            --preview 'git -C "$GZ_REPO_RESOLVED" lg --color=always {3}')
fi

[ -n "$match" ] || exit 0
printf '%s\n' "${match%%	*}"
