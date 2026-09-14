#!/bin/sh
# ProxyCommand behind `ssh <worktree>.dc`: find the running devcontainer built
# for that worktree and pipe the connection to its sshd on the docker bridge.
# Installed into ~/.ssh/config.d/devcontainers.conf by devcontainer-ssh-setup.sh
# as
#     Host *.dc
#         ProxyCommand /path/to/devcontainer-ssh-proxy.sh %h %p
# and not meant to be run by hand.
#
# Why a proxy at all: a devcontainer's sshd could be *published* on a host port
# instead, but every worktree of a project shares one tracked devcontainer.json,
# and a published port cannot be shared -- so two worktree containers running at
# once would need two different tracked lines. On the bridge nothing is
# published and nothing can collide, and the name stays the same across
# rebuilds while the container's address does not: this script looks the
# address up on every connection, by the devcontainer.local_folder label, which
# is what makes `herdr machine add firstx-wa.dc` a target that never goes stale.
#
# stdout *is* the ssh connection, so nothing but nc may write to it; every
# diagnostic goes to stderr, where ssh shows it as the reason the proxy failed.
#
# Needs the docker daemon of this distro (the bridge is only reachable from the
# host that owns it, so not from Windows and not under Docker Desktop) and the
# OpenBSD netcat, which is what ubuntu ships as `nc`.

set -u

prog=devcontainer-ssh-proxy
err() { printf '%s: %s\n' "$prog" "$*" >&2; }
die() { err "$@"; exit 1; }

[ $# -eq 2 ] || die 'usage: devcontainer-ssh-proxy.sh <worktree>.dc <port>  (a ProxyCommand; see devcontainer-ssh-setup.sh)'
name=${1%.dc} port=$2
[ "$name" != "$1" ] && [ -n "$name" ] \
    || die "not a devcontainer alias: $1 (expected <worktree>.dc)"

command -v docker >/dev/null 2>&1 || die 'docker is not on $PATH'
command -v nc     >/dev/null 2>&1 || die 'nc is not installed -- sudo apt install netcat-openbsd'

# The label is the host path of the workspace, and its last segment -- the
# worktree -- is the name. Both separators, since VS Code on Windows stamps
# `c:\SWProjekte\x` and the devcontainer cli in WSL `/mnt/c/SWProjekte/x`.
# Compared as strings, never as a pattern built from the name.
TAB=$(printf '\t')
ids=$(docker ps --filter label=devcontainer.local_folder \
        --format "{{.ID}}${TAB}{{.Label \"devcontainer.local_folder\"}}" 2>/dev/null \
      | LC_ALL=C awk -F"$TAB" -v want="$name" '
            { n = $2; sub(/[\\\/]$/, "", n); sub(/.*[\\\/]/, "", n)
              if (n == want) print $1 }')

[ -n "$ids" ] || die "no running devcontainer for worktree '$name'" \
    "-- docker ps, or start it: devcontainer-herdr.sh --container $name"

id=${ids%%
*}
if [ "$id" != "$ids" ]; then
    err "more than one running container for '$name', using $id:"
    printf '%s\n' "$ids" | sed 's/^/    /' >&2
fi

# The first network's address; a devcontainer sits on the default bridge.
ip=$(docker inspect "$id" \
        --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{"\n"}}{{end}}' 2>/dev/null \
     | sed -n '1p')
[ -n "$ip" ] || die "container $id has no bridge address"

exec nc "$ip" "$port"
