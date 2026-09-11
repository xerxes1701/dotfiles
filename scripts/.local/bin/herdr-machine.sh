#!/bin/sh
# Pick a devcontainer with fzf and hand it to herdr as a *saved machine*, so
# its workspaces and its agents appear in this herdr window next to the local
# ones -- `herdr machine add`, with the ssh target worked out for you.
#
# The point of the exercise: herdr recognizes an agent from the foreground
# process of a pane, so a pane that reaches into a container with `docker exec`
# holds `docker`, not `claude`, and the agent panel stays empty. A saved machine
# puts the agents next to the herdr server that owns them -- inside the
# container -- and that server reports them properly. `HERDR_AGENT=claude
# docker exec ... claude` is the other way out, and gives no session identity.
#
# The container side of this needs an sshd and a herdr new enough to speak
# endpoint generation 1 (0.9.0). firstx-master's devcontainer has both; see the
# "herdr from the host" section of its .devcontainer/README.md. This script
# only ever *reads* the container, so a container that is not set up for it is
# reported, not modified.
#
# POSIX sh, self-previewing and fzf-driven for the same reasons docker-shell.sh
# is: one picker reachable from every shell, and a preview fzf can re-run per
# row. Kept next to `dsh` rather than made a `dc_` launcher, because it starts
# nothing in the container -- it hands an address to the herdr on this side.

set -u

self=$(readlink -f -- "$0" 2>/dev/null) || self=$0

# Defaults for the devcontainers here: `vscode` is the remoteUser of every one
# of them, 2222 the port their sshd publishes. Both are checked against the
# container that gets picked.
user=${HERDR_MACHINE_USER-vscode}
port=${HERDR_MACHINE_PORT-2222}

US=$(printf '\037')
RS=$(printf '\036')

# Same rule as docker-shell.sh: colors for a terminal only, and never against
# NO_COLOR or TERM=dumb. fzf renders the preview into a pty, so it keeps them.
if [ -z "${NO_COLOR:-}" ] && [ "${TERM:-dumb}" != dumb ] && { [ -t 1 ] || [ -t 2 ]; }; then
    c_key=$(printf '\033[1;38;5;110m'); c_hdr=$(printf '\033[1;38;5;214m')
    c_dim=$(printf '\033[2m');          c_off=$(printf '\033[0m')
    c_ok=$(printf '\033[1;38;5;108m');  c_bad=$(printf '\033[1;38;5;174m')
else
    c_key= c_hdr= c_dim= c_off= c_ok= c_bad=
fi

die() {
    printf 'herdr-machine: %s\n' "$1" >&2
    shift
    for hint in "$@"; do printf '%s  %s%s\n' "$c_dim" "$hint" "$c_off" >&2; done
    exit 1
}

usage() {
    cat <<EOF
usage: $(basename -- "$0") [options]

Picks one of the running devcontainers with fzf and registers it with
\`herdr machine add\`, so this herdr window can hold its workspaces and agents.

  -u, --user USER    user to connect as. default: $user (\$HERDR_MACHINE_USER)
  -p, --port PORT    port its sshd listens on inside the container.
                     default: $port (\$HERDR_MACHINE_PORT)
  -l, --label TEXT   sidebar label. default: the workspace folder's name
  -s, --session NAME herdr session on the remote side (--remote-session)
  -c, --container S  preselect: fzf's initial query. With --exact, and when it
                     leaves exactly one container, that one is used unattended.
  -x, --exact        do not prompt when the query matches a single container.
  -n, --dry-run      resolve and check everything, print the command, run
                     nothing.
  -h, --help         this help.

The ssh target is worked out from the container: the host side of its published
$port maps to a \`Host\` block in ~/.ssh/config when one matches, and to a plain
\`ssh://user@host:port\` when none does. A matching Host block is preferred
because that is where the identity file and HostKeyAlias live.

  herdr-machine.sh                  pick, check, add
  herdr-machine.sh -c firstx -x     skip the picker when only one matches
  herdr-machine.sh -n               say what it would do
  herdr-machine.sh -s agents        register the remote 'agents' session

In fzf: enter registers the machine, ctrl-r reloads the list, ctrl-y copies the
container id. Saved machines are client state, not config -- an open herdr
picks a new one up within a second, and \`herdr machine list\` shows them.
EOF
}

# --- an ssh target for a container -----------------------------------------

# The host address the container's sshd is published on, "host:port", or
# nothing when that port is not published at all. A publish on every interface
# is addressed through loopback: this only ever talks to the local docker.
published_addr() {
    docker port "$1" "$2" 2>/dev/null \
        | LC_ALL=C awk -F: 'NR == 1 && NF >= 2 {
              host = $1; if (host == "0.0.0.0" || host == "::" || host == "")
                  host = "127.0.0.1"
              print host ":" $NF; exit }'
}

# A Host block in ~/.ssh/config whose resolved hostname, port and user are the
# ones we would dial. `ssh -G` is what does the resolving, so an alias that
# reaches the container through an Include, a Match block or a HostName
# indirection counts too -- which is the whole reason for asking ssh instead of
# grepping for the address.
ssh_config_host() {
    sc_host=${1%:*} sc_port=${1##*:} sc_user=$2
    [ -r "$HOME/.ssh/config" ] || return 1

    # A Host line may carry several patterns; a pattern with a wildcard or a
    # negation is not an address anybody can connect to, so it is skipped.
    sed -n 's/^[[:space:]]*[Hh][Oo][Ss][Tt][[:space:]]\{1,\}//p' "$HOME/.ssh/config" \
        | tr ' \t' '\n\n' \
        | while read -r name; do
              case $name in ''|*[*?!]*) continue ;; esac
              eval "$(ssh -G "$name" 2>/dev/null | LC_ALL=C awk '
                  $1 == "hostname" { printf "g_host=%s\n", $2 }
                  $1 == "port"     { printf "g_port=%s\n", $2 }
                  $1 == "user"     { printf "g_user=%s\n", $2 }')" || continue
              [ "${g_port-}" = "$sc_port" ] || continue
              [ "${g_user-}" = "$sc_user" ] || continue
              case ${g_host-} in
                  "$sc_host"|localhost|127.0.0.1|::1) ;;
                  *) continue ;;
              esac
              printf '%s\n' "$name"
          done | head -1
}

# What `herdr machine add` gets: the Host alias when there is one, the explicit
# URL otherwise.
ssh_target() {
    st_addr=$1 st_user=$2
    st_alias=$(ssh_config_host "$st_addr" "$st_user")
    if [ -n "$st_alias" ]; then
        printf '%s\n' "$st_alias"
    else
        printf 'ssh://%s@%s\n' "$st_user" "$st_addr"
    fi
}

# `herdr --version` in a container, or nothing.
#
# The filter is not politeness: a failed `docker exec` prints its own diagnosis
# ("executable file not found in $PATH") on *stdout*, with exit 127, so a
# container without herdr hands back a paragraph that would otherwise be shown
# as if it were a version. Only something shaped like one gets through.
remote_herdr_version() {
    docker exec "$1" herdr --version 2>/dev/null \
        | LC_ALL=C awk 'NR == 1 && $1 == "herdr" && $2 ~ /^[0-9]+\.[0-9]+/ {
              print $1 " " $2; exit }'
}

# herdr 0.9.0 is the floor on both sides: older servers are pre-endpoint-
# generation-1, which a 0.9.0 client can only show as Attention.
version_ge_090() {
    printf '%s\n' "$1" | LC_ALL=C awk '{
        n = split($NF, v, ".")
        exit !((v[1] + 0) > 0 || (v[2] + 0) >= 9) }'
}

# --- preview ---------------------------------------------------------------
# fzf calls this back as `$0 --preview <id>` for the highlighted row. Every
# probe in here is local docker or local ssh config -- nothing dials the
# container, so moving the cursor cannot hang on a network timeout. Whether the
# address actually answers is settled on selection, once.

preview() {
    pv_id=$1
    pv_cols=${FZF_PREVIEW_COLUMNS:-${COLUMNS:-80}}

    docker inspect "$pv_id" --format \
"H${US}name${US}{{ .Name }}${RS}\
H${US}folder${US}{{ index .Config.Labels \"devcontainer.local_folder\" }}${RS}\
H${US}state${US}{{ .State.Status }}{{ if .State.Health }} ({{ .State.Health.Status }}){{ end }}${RS}\
H${US}user${US}{{ if .Config.User }}{{ .Config.User }}{{ else }}root{{ end }}${RS}" 2>/dev/null \
    | LC_ALL=C awk -v RS="$RS" -v FS="$US" -v w="$pv_cols" \
          -v key="$c_key" -v off="$c_off" '
      function head(s, n) { return length(s) <= n ? s : substr(s, 1, n - 1) "…" }
      { gsub(/[\n\t]+/, " ") }
      $1 == "H" && $3 != "" {
          v = $3
          if ($2 == "name") sub(/^\//, "", v)
          printf "%s%-8s%s %s\n", key, $2, off, head(v, w - 11)
      }'

    # The four things that decide whether this container can be a machine, in
    # the order they have to be true.
    printf '\n%swhat herdr needs%s\n' "$c_hdr" "$c_off"

    # The list holds running containers only, but one can stop while the cursor
    # is on it -- and every probe below would then report its own absence
    # instead of the one cause. Say the cause.
    if [ "$(docker inspect "$pv_id" --format '{{ .State.Running }}' 2>/dev/null)" != true ]; then
        printf '  %sthis container is not running -- nothing to connect to%s\n' \
            "$c_bad" "$c_off"
        return 0
    fi

    pv_addr=$(published_addr "$pv_id" "$port")
    if [ -n "$pv_addr" ]; then
        pv_state="$c_ok$pv_addr$c_off"
    else
        pv_state="${c_bad}port $port not published$c_off"
    fi
    printf '  %-9s %s\n' 'ssh port' "$pv_state"

    if docker exec "$pv_id" pgrep -x sshd >/dev/null 2>&1; then
        printf '  %-9s %srunning%s\n' sshd "$c_ok" "$c_off"
    else
        printf '  %-9s %snot running%s\n' sshd "$c_bad" "$c_off"
    fi

    pv_herdr=$(remote_herdr_version "$pv_id")
    if [ -z "$pv_herdr" ]; then
        printf '  %-9s %snot installed%s\n' herdr "$c_bad" "$c_off"
    elif version_ge_090 "$pv_herdr"; then
        printf '  %-9s %s%s%s\n' herdr "$c_ok" "$pv_herdr" "$c_off"
    else
        printf '  %-9s %s%s -- needs 0.9.0%s\n' herdr "$c_bad" "$pv_herdr" "$c_off"
    fi

    if [ -n "$pv_addr" ]; then
        pv_target=$(ssh_target "$pv_addr" "$user")
        printf '  %-9s %s\n' target "$pv_target"
        if herdr machine list --json 2>/dev/null | grep -Fq "\"$pv_target\""; then
            printf '  %-9s %salready a saved machine%s\n' saved "$c_dim" "$c_off"
        fi
    fi

    # The agents that are already running in there, which is what the machine
    # is for. Read from the container's own herdr, so an empty answer means
    # "no server or no agents", not "not reachable".
    printf '\n%sagents in this container%s\n' "$c_hdr" "$c_off"
    # Counted on matches rather than on input lines, for the same reason the
    # version is filtered: a failed exec still writes a line to stdout, and
    # "nothing matched" is the question here, not "nothing arrived".
    docker exec -u "$user" "$pv_id" herdr agent list 2>/dev/null \
        | LC_ALL=C awk -v dim="$c_dim" -v off="$c_off" '
            { while (match($0, /"agent":"[^"]*"/)) {
                  a = substr($0, RSTART + 9, RLENGTH - 10)
                  s = ""
                  if (match($0, /"agent_status":"[^"]*"/))
                      s = substr($0, RSTART + 16, RLENGTH - 17)
                  printf "  %s  %s%s%s\n", a, dim, s, off
                  found++
                  $0 = substr($0, RSTART + RLENGTH) } }
            END { if (!found) printf "  %s(no herdr server running in there yet)%s\n", dim, off }'
}

if [ "${1-}" = --preview ]; then
    [ $# -eq 2 ] || die 'usage: --preview <container-id>'
    preview "$2"
    exit 0
fi

# --- options ---------------------------------------------------------------

query= exact= label= session= dry=
while [ $# -gt 0 ]; do
    case $1 in
        -u|--user)      [ $# -ge 2 ] || die "$1 needs a user";      user=$2;    shift 2 ;;
        -p|--port)      [ $# -ge 2 ] || die "$1 needs a port";      port=$2;    shift 2 ;;
        -l|--label)     [ $# -ge 2 ] || die "$1 needs a label";     label=$2;   shift 2 ;;
        -s|--session)   [ $# -ge 2 ] || die "$1 needs a name";      session=$2; shift 2 ;;
        -c|--container) [ $# -ge 2 ] || die "$1 needs a filter";    query=$2;   shift 2 ;;
        -x|--exact)     exact=1; shift ;;
        -n|--dry-run)   dry=1; shift ;;
        -h|--help)      usage; exit 0 ;;
        --)             shift; break ;;
        *)              die "unknown argument: $1  (--help)" ;;
    esac
done
[ $# -eq 0 ] || die "unknown argument: $1  (--help)"

command -v docker >/dev/null 2>&1 || die 'docker is not on $PATH'
command -v fzf    >/dev/null 2>&1 || die 'fzf is not on $PATH'
command -v ssh    >/dev/null 2>&1 || die 'ssh is not on $PATH'
command -v herdr  >/dev/null 2>&1 || die 'herdr is not on $PATH'

herdr_local=$(herdr --version 2>/dev/null)
version_ge_090 "$herdr_local" || die \
    "this herdr is ${herdr_local:-too old} -- saved machines arrived in 0.9.0" \
    'detach from the session, then: herdr update'

# --- the list --------------------------------------------------------------
# Only devcontainers, by the label the dc_ launchers pick by, and only running
# ones: there is no sshd to reach in a stopped container. Use
# devcontainer-herdr.sh (which starts one) or dsh if that is what you meant.

fmt='{{.ID}}\t{{.Label "devcontainer.local_folder"}}\t{{.Names}}\t{{.Status}}'
TAB=$(printf '\t')
# The label is a host path, and its last segment -- the worktree -- is the part
# that identifies the container. Windows separators included, since these
# labels come from Windows folders.
list="docker ps --filter label=devcontainer.local_folder --format '$fmt' \
  | awk -F'\t' '{ n = \$2; sub(/[\\\\\\/]\$/, \"\", n); sub(/.*[\\\\\\/]/, \"\", n)
                  print \$1 \"\t\" n \"\t\" \$3 \"\t\" \$4 }' \
  | column -t -s '$TAB'"

rows=$(eval "$list") || die 'docker ps failed'
[ -n "$rows" ] || die 'no running devcontainers' \
    'a stopped one first: devcontainer-herdr.sh --list' \
    'any other container: dsh'

pick=
if [ -n "$query" ]; then
    hits=$(printf '%s\n' "$rows" | fzf --filter="$query" 2>/dev/null)
    [ -n "$hits" ] || die "no running devcontainer matches: $query"
    if [ -n "$exact" ] && [ "$(printf '%s\n' "$hits" | wc -l)" -eq 1 ]; then
        pick=$hits
    fi
fi

if [ -z "$pick" ]; then
    # fish enables the kitty keyboard protocol and fzf does not implement it
    # (junegunn/fzf#3208), so key-release events would arrive as literal text
    # in fzf's prompt. Same reset docker-shell.sh does, for the same reason.
    [ -t 2 ] && printf '\033[=0;1u' >/dev/tty 2>/dev/null

    pick=$(printf '%s\n' "$rows" | HERDR_MACHINE_USER="$user" HERDR_MACHINE_PORT="$port" fzf \
        --ansi --height=90% --reverse --border=rounded \
        --query="$query" \
        --header='enter add machine   ^R reload   ^Y copy id' \
        --preview="'$self' --preview {1}" \
        --preview-window='right,60%,border-left,wrap' \
        --bind="ctrl-r:reload($list)" \
        --bind="ctrl-y:execute-silent(printf %s {1} | $(
            if   command -v wl-copy  >/dev/null 2>&1; then echo wl-copy
            elif command -v clip.exe >/dev/null 2>&1; then echo clip.exe
            elif command -v xclip    >/dev/null 2>&1; then echo 'xclip -selection clipboard'
            else echo 'cat >/dev/null'; fi))")
    st=$?
    [ $st -eq 0 ] || { [ $st -eq 130 ] && exit 0; die "fzf exited $st"; }
fi

id=${pick%% *}
[ -n "$id" ] || die 'no container selected'
folder=$(docker inspect "$id" --format \
    '{{ index .Config.Labels "devcontainer.local_folder" }}' 2>/dev/null)
# The worktree name, for the sidebar label -- the same segment the list shows.
[ -n "$label" ] || label=$(printf '%s\n' "$folder" \
    | sed 's![\\/]$!!; s!.*[\\/]!!')
[ -n "$label" ] || label=$(docker inspect "$id" --format '{{ .Name }}' \
    | sed 's!^/!!')

# --- checks ----------------------------------------------------------------
# In the order that makes a failure say something useful: an address before a
# connection, a connection before a version, and a version before herdr is
# asked to do anything.

addr=$(published_addr "$id" "$port")
[ -n "$addr" ] || die "container $label does not publish port $port" \
    'its devcontainer.json needs the port, e.g.' \
    '  "appPort": ["127.0.0.1:2222:2222"]' \
    'and the container has to be *recreated* for that, not restarted' \
    "another port: --port N" \
    'see the "herdr from the host" section of .devcontainer/README.md'

target=$(ssh_target "$addr" "$user")

if herdr machine list --json 2>/dev/null | grep -Fq "\"$target\""; then
    printf '%s%s is already a saved machine (%s)%s\n' \
        "$c_dim" "$label" "$target" "$c_off"
    printf '%s  herdr machine list          what is registered\n' "$c_dim"
    printf '  herdr machine remove <id>   to register it differently%s\n' "$c_off"
    exit 0
fi

# herdr's own connections are non-interactive: a host key it has never seen
# leaves the machine in Attention rather than asking. So the first connection
# is made here, in the foreground, where a question can be answered -- and
# `ssh` is also the shortest proof that the key, the user and the port work.
probe() { ssh -o ConnectTimeout=5 "$@" "$target" 'herdr --version' 2>&1; }

herdr_remote=$(probe -o BatchMode=yes) || {
    case $herdr_remote in
        *"Host key verification failed"*|*"authenticity of host"*|*"Host key for"*)
            printf '%sfirst connection to %s -- accept its host key%s\n' \
                "$c_hdr" "$target" "$c_off" >&2
            printf '%sit should match the fingerprint init-sshd.sh logged on start%s\n' \
                "$c_dim" "$c_off" >&2
            herdr_remote=$(probe) || die \
                "ssh $target failed" "$herdr_remote"
            ;;
        *'herdr: command not found'*|*'herdr: not found'*)
            # ssh itself worked -- this is the remote PATH, which for a
            # non-interactive session comes from /etc/environment and sshd's
            # own default, not from the container's shell config.
            die "ssh $target works, but herdr is not on its PATH" \
                "$herdr_remote" \
                'the image installs it in /usr/local/bin; check the container:' \
                "  docker exec $id command -v herdr"
            ;;
        *)
            die "ssh $target failed" "$herdr_remote" \
                'the container publishes the port, so this is authentication or' \
                'the sshd itself: docker exec '"$id"' pgrep -x sshd' \
                'and its log: docker exec '"$id"' tail /var/log/sshd.log'
            ;;
    esac
}

version_ge_090 "$herdr_remote" || die \
    "herdr in $label is ${herdr_remote:-missing} -- saved machines need 0.9.0" \
    'bump HERDR_VERSION in its .devcontainer/Dockerfile and rebuild' \
    'a 0.9.0 client can only show an older server as Attention'

# --- add -------------------------------------------------------------------

set -- machine add "$target" --label "$label"
[ -z "$session" ] || set -- "$@" --remote-session "$session"

printf '%s%s%s  %s%s -> %s%s\n' \
    "$c_hdr" "$label" "$c_off" "$c_dim" "$herdr_remote" "$target" "$c_off"

if [ -n "$dry" ]; then
    printf '%swould run: herdr %s%s\n' "$c_dim" "$*" "$c_off"
    exit 0
fi

herdr "$@" || die 'herdr machine add failed' \
    'it starts the remote server before saving the profile, so this may be' \
    'the server side; run it by hand to see the prompts:' \
    "  herdr machine add $target --label '$label'"

printf '%sadded%s  open herdr and pick %s in the sidebar' "$c_ok" "$c_off" "$label"
[ "${HERDR_ENV:-}" = 1 ] && printf ' -- an attached client sees it within a second'
printf '\n'
