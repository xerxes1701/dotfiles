#!/bin/sh
# ProxyCommand behind `ssh win` from WSL: make sure the user-scope sshd on the
# Windows host is up, then pipe the connection to it. Goes into
# ~/.ssh/config.d/windows-host.conf as
#     Host win
#         Port 2222
#         User <windows account>
#         ProxyCommand /path/to/windows-host-ssh-proxy.sh %h %p
# and is not meant to be run by hand. The Windows half is
# windows-sshd-user.ps1, in this same directory of the Windows checkout, and
# its header says why there is no service and no port 22.
#
# Why a proxy at all: that sshd is a plain process of the logged-on user, so
# nothing starts it at boot -- the WSL side does, right before it connects,
# through interop; a second call while it runs is a no-op. And it binds to the
# WSL adapter alone, whose address is picked per Windows boot: from in here that
# address is the default gateway, looked up on every connection rather than
# written into a HostName that goes stale.
#
# stdout *is* the ssh connection, so nothing but nc may write to it; every
# diagnostic goes to stderr, where ssh shows it as the reason the proxy failed.
#
# Needs WSL2 in NAT mode (the default; with networkingMode=mirrored the host
# is 127.0.0.1 and no proxy is needed), interop enabled, and the OpenBSD
# netcat, which is what ubuntu ships as `nc`.

set -u

prog=windows-host-ssh-proxy
err() { printf '%s: %s\n' "$prog" "$*" >&2; }
die() { err "$@"; exit 1; }

[ $# -eq 2 ] || die 'usage: windows-host-ssh-proxy.sh <alias> <port>  (a ProxyCommand; see the README, windows)'
port=$2

ps=/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe
[ -x "$ps" ]    || die 'powershell.exe is not reachable -- not WSL, or interop is off'
command -v nc >/dev/null 2>&1 || die 'nc is not installed -- sudo apt install netcat-openbsd'

gw=$(ip route show default 2>/dev/null | awk '{ print $3; exit }')
[ -n "$gw" ] || die 'no default route -- is this WSL2 in NAT mode?'

# The launcher sits in the Windows checkout, %USERPROFILE%\dotfiles, which is
# where the README puts it; resolved on the Windows side so this works for any
# account. Its output is progress or the reason it failed, so stderr.
"$ps" -NoProfile -ExecutionPolicy Bypass -Command \
    "& \"\$env:USERPROFILE\dotfiles\scripts\.local\bin\windows-sshd-user.ps1\" -Port $port" >&2 </dev/null \
    || die "could not start sshd on the windows host (gateway $gw)"

exec nc "$gw" "$port"
