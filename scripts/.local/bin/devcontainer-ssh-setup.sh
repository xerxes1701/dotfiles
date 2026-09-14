#!/bin/sh
# Configure this WSL host once, so that `ssh <worktree>.dc` reaches the running
# devcontainer built for that worktree -- and with it `herdr machine add
# <worktree>.dc`, which is what herdr-machine.sh registers.
#
# What it sets up, and nothing else:
#   * ~/.ssh/config.d/devcontainers.conf -- one `Host *.dc` block whose
#     ProxyCommand is devcontainer-ssh-proxy.sh. Generated here, from the
#     heredoc below, so re-running this script is how it is updated.
#   * an `Include config.d/*.conf` as the first directive of ~/.ssh/config.
#     First, because an Include that comes after a `Host` block belongs to that
#     block. Nothing else in that file is touched, and a backup is taken before
#     the one edit.
#
# Why the bridge and not a published port: every worktree of a project shares
# one tracked devcontainer.json, and a published host port cannot be shared, so
# two worktree containers running at once would need two different tracked
# lines. The bridge address is reachable from this distro directly, nothing is
# published, and the proxy looks the address up per connection -- the name
# `firstx-wa.dc` stays valid across rebuilds. The price: the container is not
# reachable from Windows any more, and none of this works under Docker Desktop,
# whose bridge lives in its own VM. Both are checked and said.
#
# Idempotent: run it again after a change to this script, or to see the state.
# -n resolves and checks everything and prints what it would write.

set -u

prog=devcontainer-ssh-setup
ssh_dir=$HOME/.ssh
conf_dir=$ssh_dir/config.d
conf=$conf_dir/devcontainers.conf
main_conf=$ssh_dir/config
include_line='Include config.d/*.conf'
suffix=.dc
remote_user=vscode
remote_port=2222

if [ -z "${NO_COLOR:-}" ] && [ "${TERM:-dumb}" != dumb ] && { [ -t 1 ] || [ -t 2 ]; }; then
    c_key=$(printf '\033[1;38;5;110m'); c_hdr=$(printf '\033[1;38;5;214m')
    c_dim=$(printf '\033[2m');          c_off=$(printf '\033[0m')
    c_ok=$(printf '\033[1;38;5;108m');  c_bad=$(printf '\033[1;38;5;174m')
else
    c_key= c_hdr= c_dim= c_off= c_ok= c_bad=
fi

die() {
    printf '%s: %s\n' "$prog" "$1" >&2
    shift
    for hint in "$@"; do printf '%s  %s%s\n' "$c_dim" "$hint" "$c_off" >&2; done
    exit 1
}
warn() { printf '%swarning:%s %s\n' "$c_bad" "$c_off" "$1" >&2; }
row()  { printf '  %s%-10s%s %s\n' "$c_key" "$1" "$c_off" "$2"; }
ok()   { row "$1" "$c_ok$2$c_off"; }
bad()  { row "$1" "$c_bad$2$c_off"; }

usage() {
    cat <<EOF
usage: $(basename -- "$0") [-n] [-h]

Sets this host up so that \`ssh <worktree>$suffix\` reaches the running
devcontainer built for that worktree, on the docker bridge, through
devcontainer-ssh-proxy.sh. Writes $conf and makes sure
~/.ssh/config includes it. Idempotent.

  -n, --dry-run   check everything, print what would be written, change nothing
  -h, --help      this help

Afterwards: herdr-machine.sh registers a container as a herdr saved machine
with that name as the target.
EOF
}

dry=
while [ $# -gt 0 ]; do
    case $1 in
        -n|--dry-run) dry=1; shift ;;
        -h|--help)    usage; exit 0 ;;
        *)            die "unknown argument: $1  (--help)" ;;
    esac
done

# --- prerequisites ---------------------------------------------------------
# In the order a failure should be reported: tools, then the daemon, then the
# one thing that decides whether the bridge is reachable from here at all.

printf '%swhat the proxy needs%s\n' "$c_hdr" "$c_off"

command -v ssh    >/dev/null 2>&1 || die 'ssh is not on $PATH'
command -v docker >/dev/null 2>&1 || die 'docker is not on $PATH'

# `Include` arrived in OpenSSH 7.3.
ssh_ver=$(ssh -V 2>&1 | sed -n 's/^OpenSSH_\([0-9]*\)\.\([0-9]*\).*/\1 \2/p')
set -- ${ssh_ver:-0 0}
if [ "$1" -gt 7 ] || { [ "$1" -eq 7 ] && [ "$2" -ge 3 ]; }; then
    ok ssh "OpenSSH $1.$2"
else
    die "OpenSSH ${ssh_ver:-unknown} -- Include needs 7.3 or newer"
fi

if command -v nc >/dev/null 2>&1; then
    ok nc "$(command -v nc)"
else
    die 'nc is not installed' 'sudo apt install netcat-openbsd'
fi

proxy=$(command -v devcontainer-ssh-proxy.sh 2>/dev/null) \
    || die 'devcontainer-ssh-proxy.sh is not on $PATH' \
           'it lives next to this script in the dotfiles; deploy them: stow-deploy.sh'
# The absolute path, resolved through the stow link: ssh runs the ProxyCommand
# with the PATH of whatever started it, and herdr's background connections
# start from herdr, not from a login shell.
proxy=$(readlink -f -- "$proxy" 2>/dev/null) || die "cannot resolve $proxy"
ok proxy "$proxy"

docker info >/dev/null 2>&1 || die 'the docker daemon does not answer' 'is docker running in this distro?'

# The bridge is reachable only from the host that owns it: the gateway address
# docker hands out has to be an interface *here*. Under Docker Desktop it is an
# interface of the desktop VM, and this whole path is not available.
gateway=$(docker network inspect bridge \
            --format '{{range .IPAM.Config}}{{.Gateway}}{{end}}' 2>/dev/null)
[ -n "$gateway" ] || die 'docker has no bridge network'
if ip -4 -o addr show 2>/dev/null | grep -Fq " $gateway/"; then
    ok bridge "$gateway is an interface of this distro"
else
    die "the bridge gateway $gateway is not an interface here" \
        'this is Docker Desktop or a remote daemon: the bridge is not reachable' \
        'from this distro. A container reached that way needs a published port,' \
        'which herdr-machine.sh still handles.'
fi

# herdr is the consumer, not a prerequisite of the ssh side; say what is there.
if herdr_v=$(herdr --version 2>/dev/null); then
    ok herdr "$herdr_v"
else
    warn 'herdr is not on $PATH -- the ssh alias works without it, herdr-machine.sh does not'
fi

# --- the include file ------------------------------------------------------

want=$(cat <<EOF
# Written by devcontainer-ssh-setup.sh (dotfiles). Re-run that to update; a
# hand edit is overwritten by the next run.
#
# \`ssh <worktree>$suffix\` reaches the running devcontainer built for that
# worktree, on the docker bridge: the ProxyCommand looks the container up by
# its devcontainer.local_folder label and pipes to its sshd. No HostName --
# the alias is the name that goes into known_hosts, one entry per worktree,
# which is what a per-worktree host key on the container side pairs with.
Host *$suffix
    Port $remote_port
    User $remote_user
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
    ProxyCommand $proxy %h %p
EOF
)

printf '\n%s%s%s\n' "$c_hdr" "$conf" "$c_off"
if [ -f "$conf" ] && [ "$(cat "$conf")" = "$want" ]; then
    ok content unchanged
elif [ -n "$dry" ]; then
    if [ -f "$conf" ]; then bad content 'differs -- would be rewritten'
    else bad content 'missing -- would be written'; fi
    printf '%s\n' "$want" | sed "s/^/  ${c_dim}|${c_off} /"
else
    [ -d "$ssh_dir" ] || install -d -m 0700 "$ssh_dir"
    install -d -m 0700 "$conf_dir"
    printf '%s\n' "$want" > "$conf.tmp" && chmod 0600 "$conf.tmp" \
        && mv -f "$conf.tmp" "$conf" || die "cannot write $conf"
    ok content written
fi

# --- the Include -----------------------------------------------------------
# ssh keeps the first value it sees for every option, and a directive inside
# a `Host` block is conditional on that block. So the Include has to come
# before the first `Host`/`Match` -- which, in a config that starts with
# `Host github.com`, means line 1.

printf '\n%s%s%s\n' "$c_hdr" "$main_conf" "$c_off"

inc_at=0 host_at=0
if [ -f "$main_conf" ]; then
    inc_at=$(LC_ALL=C awk -v want="$include_line" '
        { line = $0; sub(/^[ \t]+/, "", line); sub(/[ \t]+$/, "", line) }
        tolower(line) == tolower(want) { print NR; exit }' "$main_conf")
    host_at=$(LC_ALL=C awk '
        tolower($1) == "host" || tolower($1) == "match" { print NR; exit }' "$main_conf")
    : "${inc_at:=0}" "${host_at:=0}"
fi

if [ "$inc_at" -gt 0 ] && { [ "$host_at" -eq 0 ] || [ "$inc_at" -lt "$host_at" ]; }; then
    ok include "line $inc_at"
else
    if [ "$inc_at" -gt 0 ]; then
        warn "the Include on line $inc_at comes after the first Host block (line $host_at) and is scoped to it"
        printf '%s  it will be added at the top; remove the one on line %s by hand%s\n' \
            "$c_dim" "$inc_at" "$c_off" >&2
    fi
    if [ -n "$dry" ]; then
        bad include 'missing -- would be inserted as line 1'
    else
        if [ -f "$main_conf" ]; then
            backup="$main_conf.bak-$(date +%Y%m%d)"
            [ -e "$backup" ] || cp -p -- "$main_conf" "$backup"
        else
            [ -d "$ssh_dir" ] || install -d -m 0700 "$ssh_dir"
            : > "$main_conf"; chmod 0600 "$main_conf"; backup=
        fi
        {
            printf '# devcontainers on the docker bridge, written by devcontainer-ssh-setup.sh\n'
            printf '%s\n\n' "$include_line"
            cat "$main_conf"
        } > "$main_conf.tmp" && chmod 0600 "$main_conf.tmp" \
            && mv -f "$main_conf.tmp" "$main_conf" || die "cannot write $main_conf"
        ok include "inserted as line 2${backup:+  (backup: $backup)}"
    fi
fi

# --- verify ----------------------------------------------------------------
# What ssh itself resolves for a name of that shape -- the only check that
# counts, and it costs no connection.

printf '\n%sssh -G probe%s%s\n' "$c_hdr" "$suffix" "$c_off"
resolved=$(ssh -G "probe$suffix" 2>/dev/null)
g_proxy=$(printf '%s\n' "$resolved" | LC_ALL=C awk '$1 == "proxycommand" { $1 = ""; sub(/^ /, ""); print; exit }')
g_user=$(printf '%s\n'  "$resolved" | LC_ALL=C awk '$1 == "user" { print $2; exit }')
g_port=$(printf '%s\n'  "$resolved" | LC_ALL=C awk '$1 == "port" { print $2; exit }')
verified=1
case ${g_proxy-} in
    *devcontainer-ssh-proxy*) ok proxycommand "$g_proxy" ;;
    *) bad proxycommand "${g_proxy:-none}"; verified= ;;
esac
if [ "${g_user-}" = "$remote_user" ]; then ok user "$g_user"; else bad user "${g_user:-?}"; verified=; fi
if [ "${g_port-}" = "$remote_port" ]; then ok port "$g_port"; else bad port "${g_port:-?}"; verified=; fi
if [ -z "$verified" ] && [ -z "$dry" ]; then
    die 'ssh does not resolve the alias as written' \
        "an earlier Host block in $main_conf may match *$suffix first; ssh keeps the first value"
fi

# --- what the published-port scheme left behind ----------------------------
# Reported, never removed: these are hand-written blocks and saved profiles.

legacy=
if [ -f "$main_conf" ]; then
    legacy=$(sed -n 's/^[[:space:]]*[Hh][Oo][Ss][Tt][[:space:]]\{1,\}//p' "$main_conf" \
        | tr ' \t' '\n\n' \
        | while read -r name; do
              case $name in ''|*[*?!]*|*"$suffix") continue ;; esac
              ssh -G "$name" 2>/dev/null | LC_ALL=C awk -v name="$name" -v port="$remote_port" -v user="$remote_user" '
                  $1 == "hostname" { h = $2 } $1 == "port" { p = $2 } $1 == "user" { u = $2 }
                  END { if (p == port && u == user && (h == "127.0.0.1" || h == "localhost" || h == "::1")) print name }'
          done)
fi
machines=
if command -v herdr >/dev/null 2>&1; then
    machines=$(herdr machine list --json 2>/dev/null | LC_ALL=C awk -v suffix="$suffix" '
        /"id":/     { id = $0; sub(/.*"id": *"/, "", id); sub(/".*/, "", id) }
        /"target":/ { t = $0; sub(/.*"target": *"/, "", t); sub(/".*/, "", t)
                      if (substr(t, length(t) - length(suffix) + 1) != suffix)
                          printf "%s  %s\n", id, t }')
fi
if [ -n "$legacy$machines" ]; then
    printf '\n%sleft over from the published-port scheme%s\n' "$c_hdr" "$c_off"
    for name in $legacy; do
        row "Host" "$name  ${c_dim}-> 127.0.0.1:$remote_port; remove the block and: ssh-keygen -R $name$c_off"
    done
    printf '%s\n' "$machines" | while read -r id target; do
        [ -n "$id" ] || continue
        row "machine" "$target  ${c_dim}herdr machine remove $id  -- then herdr-machine.sh$c_off"
    done
    printf '%s  a container that still publishes %s keeps working either way until it is recreated%s\n' \
        "$c_dim" "$remote_port" "$c_off"
fi

# --- next ------------------------------------------------------------------

printf '\n'
if [ -n "$dry" ]; then
    printf '%sdry run -- nothing was written%s\n' "$c_dim" "$c_off"
else
    printf '%sdone%s  ssh <worktree>%s reaches a running devcontainer; herdr-machine.sh registers one\n' \
        "$c_ok" "$c_off" "$suffix"
fi
printf '%s  the container side: an sshd on %s and herdr 0.9.0 -- see "herdr from the host"\n' "$c_dim" "$remote_port"
printf '  in the project'"'"'s .devcontainer/README.md; a container that still publishes the port\n'
printf '  is reached on the bridge all the same, the rebuild only drops the publish%s\n' "$c_off"
