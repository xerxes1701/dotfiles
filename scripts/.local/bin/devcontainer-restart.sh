#!/bin/sh
# Restart devcontainers without rebuilding them -- stop the existing container
# and `devcontainer up` it again, so postStartCommand runs: the firewall and
# the sshd of these containers come from it, and a bare `docker start` (after
# a WSL restart, or from dc_ensure_running) skips it.
# A project without a container to restart is rebuilt instead.
#
# devcontainer-rebuild.sh --restart, under a name of its own: that script
# already works out which container VS Code considers *the* one for a folder,
# and a restart has to find exactly that one again -- the wrong labels would
# have `up` build a second container instead. Same picker, same options:
#
#   devcontainer-restart.sh                  pick one or several
#   devcontainer-restart.sh firstx-c         by name
#   devcontainer-restart.sh -n firstx-c      the commands, without running them

# readlink -f, so this still finds its sibling when reached through the
# symlink that stowing `scripts` puts in ~/.local/bin.
exec "$(dirname -- "$(readlink -f -- "$0")")/devcontainer-rebuild.sh" --restart "$@"
