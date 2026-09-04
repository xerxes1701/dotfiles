#!/usr/bin/env bash
# Open Neovim inside a running devcontainer, in its /workspaces folder.
#
# The devcontainer image carries nvim and stows this dotfiles repo (see the
# README section "devcontainer"), so the editor in there is the same one as on
# the host. Getting to it by hand means repeating four details every time:
# which container, which user, which directory, and a TERM the container's
# terminfo actually knows. This script derives all four.
#
# It talks to docker directly rather than through `devcontainer exec`, because
# the CLI re-resolves devcontainer.json on every call (seconds), and because it
# matches containers by the host path it was given -- which never matches a
# container that VS Code on Windows started, whose devcontainer.local_folder
# label is a Windows path.

set -uo pipefail

self=$(basename -- "$0")

# --- output ----------------------------------------------------------------

# Colors only for a terminal, and never against NO_COLOR (https://no-color.org)
# or TERM=dumb. Diagnostics go to stderr, the -l table to stdout, so the two
# streams get their own decision.
if [ -z "${NO_COLOR:-}" ] && [ "${TERM:-dumb}" != dumb ] && [ -t 2 ]; then
    e_bold=$'\033[1m' e_dim=$'\033[2m' e_red=$'\033[1;31m'
    e_yellow=$'\033[33m' e_cyan=$'\033[36m' e_off=$'\033[0m'
else
    e_bold='' e_dim='' e_red='' e_yellow='' e_cyan='' e_off=''
fi
if [ -z "${NO_COLOR:-}" ] && [ "${TERM:-dumb}" != dumb ] && [ -t 1 ]; then
    o_bold=$'\033[1m' o_off=$'\033[0m'
else
    o_bold='' o_off=''
fi

# die prints the reason loudly and, when given more arguments, one dim hint
# line each -- what to do about it, which is what a caller actually needs.
die() {
    printf '%serror:%s %s%s%s\n' "$e_red" "$e_off" "$e_bold" "$1" "$e_off" >&2
    shift
    for hint in "$@"; do printf '%s  %s%s\n' "$e_dim" "$hint" "$e_off" >&2; done
    exit 1
}
warn() { printf '%swarning:%s %s\n' "$e_yellow" "$e_off" "$1" >&2; }
note() { printf '%s%s%s\n' "$e_cyan" "$1" "$e_off" >&2; }

usage() {
    printf '%susage:%s %s [options] [--] [nvim args...]\n\n' "$o_bold" "$o_off" "$self"
    cat <<EOF
  -c, --container NAME  container name or id. default: the only running
                        devcontainer; with several running the script asks,
                        defaulting to the one whose workspace holds the
                        current directory.
  -u, --user NAME       user to run as. default: the container's remoteUser.
  -d, --dir DIR         directory to start in. absolute, or relative to
                        /workspaces. default: the workspace folder of the
                        chosen container.
  -l, --list            list running devcontainers and exit.
  -h, --help            this help.

Arguments after the options go to nvim unchanged and are resolved inside the
container, relative to the start directory -- a host path is not translated.
Put \`--\` before any nvim argument that starts with a dash:

  $self README.md
  $self -d firstx-master/Kh.Core src/Foo.cs
  $self -- --headless +PlugStatus +qa
EOF
}

# --- container discovery ---------------------------------------------------

# A devcontainer is any container labeled with the host folder it was started
# from. Format: id<TAB>name<TAB>local_folder.
list_containers() {
    docker ps --filter 'label=devcontainer.local_folder' \
        --format '{{.ID}}	{{.Names}}	{{.Label "devcontainer.local_folder"}}'
}

# Compare host paths across the WSL/Windows divide: VS Code on Windows labels
# the container "c:\SWProjekte\firstx-master", while the same directory is
# /mnt/c/SWProjekte/firstx-master in here. Lowercase, forward slashes, drive
# letter turned into a /mnt mount point.
normalize_path() {
    printf '%s' "$1" \
        | tr 'A-Z\\' 'a-z/' \
        | sed -E 's#^([a-z]):/#/mnt/\1/#; s#/+$##'
}

# --- options ---------------------------------------------------------------

container='' user='' dir='' do_list=0

# Long and short forms both, --opt=value included. getopts would cover only
# the short ones.
need_value() {
    [ -n "$2" ] || die "option $1 needs a value" "see $self --help"
}
while [ $# -gt 0 ]; do
    case $1 in
        -c|--container) need_value "$1" "${2:-}"; container=$2; shift 2 ;;
        --container=*)  container=${1#*=}; need_value --container "$container"; shift ;;
        -u|--user)      need_value "$1" "${2:-}"; user=$2; shift 2 ;;
        --user=*)       user=${1#*=}; need_value --user "$user"; shift ;;
        -d|--dir)       need_value "$1" "${2:-}"; dir=$2; shift 2 ;;
        --dir=*)        dir=${1#*=}; need_value --dir "$dir"; shift ;;
        -l|--list)      do_list=1; shift ;;
        -h|--help)      usage; exit 0 ;;
        --)             shift; break ;;
        -?*)            die "unknown option $1" \
                            "arguments for nvim itself go after --, e.g. $self -- --headless" \
                            "see $self --help" ;;
        *)              break ;;
    esac
done

command -v docker >/dev/null \
    || die 'docker is not on PATH' 'this script runs on the host, not inside the container'

if [ "$do_list" = 1 ]; then
    found=$(list_containers)
    [ -n "$found" ] || die 'no running devcontainer' 'start it in VS Code, or run `devcontainer up`'
    printf '%sCONTAINER ID\tNAME\tHOST FOLDER%s\n%s\n' "$o_bold" "$o_off" "$found" \
        | column -t -s "$(printf '\t')"
    exit 0
fi

# --- pick the container ----------------------------------------------------

local_folder=''

if [ -n "$container" ]; then
    docker inspect --format '{{.State.Running}}' "$container" 2>/dev/null | grep -qx true \
        || die "container \"$container\" is not running" "run $self --list to see what is"
    cid=$container
    local_folder=$(docker inspect --format '{{index .Config.Labels "devcontainer.local_folder"}}' "$cid" 2>/dev/null)
else
    candidates=$(list_containers)
    [ -n "$candidates" ] \
        || die 'no running devcontainer' 'start it in VS Code, or run `devcontainer up`'

    # More than one running: the choice is the user's. The workspace that
    # contains $PWD is offered as the default, because that is nearly always
    # the one meant -- offered, not taken silently.
    if [ "$(printf '%s\n' "$candidates" | wc -l)" -gt 1 ]; then
        here=$(normalize_path "$PWD")
        ids=() names=() folders=()
        default=0
        while IFS=$'\t' read -r id name folder; do
            ids+=("$id"); names+=("$name"); folders+=("$folder")
            case "$here/" in
                "$(normalize_path "$folder")"/*) default=${#ids[@]} ;;
            esac
        done <<< "$candidates"
        n=${#ids[@]}

        [ -t 0 ] && [ -t 2 ] || {
            warn 'several devcontainers are running:'
            printf '%s\n' "$candidates" | sed 's/^/  /' >&2
            die 'no terminal to ask on' "name one with --container, or run $self --list"
        }

        note 'several devcontainers are running:'
        for ((i = 1; i <= n; i++)); do
            if [ "$i" = "$default" ]; then
                printf '%s* %d) %-20s %s%s\n' "$e_bold" "$i" "${names[i-1]}" "${folders[i-1]}" "$e_off" >&2
            else
                printf '  %d) %-20s %s\n' "$i" "${names[i-1]}" "${folders[i-1]}" >&2
            fi
        done
        prompt="which one? [1-$n]"
        [ "$default" != 0 ] && prompt="$prompt, default $default (holds the current directory)"
        while :; do
            printf '%s%s:%s ' "$e_cyan" "$prompt" "$e_off" >&2
            read -r choice || { printf '\n' >&2; die 'nothing chosen'; }
            [ -z "$choice" ] && [ "$default" != 0 ] && choice=$default
            case $choice in
                ''|*[!0-9]*) ;;
                *) if [ "$choice" -ge 1 ] && [ "$choice" -le "$n" ]; then break; fi ;;
            esac
            warn "enter a number between 1 and $n"
        done
        candidates="${ids[choice-1]}	${names[choice-1]}	${folders[choice-1]}"
    fi

    IFS=$'\t' read -r cid _ local_folder <<< "$candidates"
fi

# --- pick the user ---------------------------------------------------------

# The image itself runs as root; the user to become is in the devcontainer
# metadata label, which is a JSON array of merged config fragments. The last
# remoteUser in it is the effective one.
if [ -z "$user" ]; then
    metadata=$(docker inspect --format '{{index .Config.Labels "devcontainer.metadata"}}' "$cid" 2>/dev/null)
    if command -v jq >/dev/null; then
        user=$(printf '%s' "$metadata" | jq -r '[.[]? | .remoteUser // empty] | last // empty' 2>/dev/null)
    else
        user=$(printf '%s' "$metadata" | grep -o '"remoteUser"[[:space:]]*:[[:space:]]*"[^"]*"' \
            | tail -n1 | sed 's/.*"\([^"]*\)"$/\1/')
    fi
    [ -n "$user" ] || user=root
fi

# --- pick the directory ----------------------------------------------------

case ${dir:-} in
    '')   workdir="/workspaces/$(basename -- "$(printf '%s' "$local_folder" | tr '\\' '/' | sed 's#/*$##')")" ;;
    /*)   workdir=$dir ;;
    *)    workdir="/workspaces/$dir" ;;
esac

# One round trip for everything that has to be true in there: the directory
# exists, nvim is installed, and the container knows our TERM. A terminfo the
# container lacks (ghostty, wezterm) leaves nvim with a crippled or unusable
# display, and the message it prints does not say TERM is the reason.
probe=$(docker exec -e PROBE_DIR="$workdir" -e PROBE_TERM="${TERM:-}" "$cid" sh -c '
    [ -d "$PROBE_DIR" ] && echo dir_ok=1 || echo dir_ok=0
    command -v nvim >/dev/null && echo nvim_ok=1 || echo nvim_ok=0
    [ -n "$PROBE_TERM" ] && infocmp "$PROBE_TERM" >/dev/null 2>&1 && echo term_ok=1 || echo term_ok=0
    echo "entries=$(ls -1 /workspaces 2>/dev/null | tr "\n" " ")"
') || die "cannot run a command in container $cid" 'is it still running?'

dir_ok=0 nvim_ok=0 term_ok=0 entries=''
while IFS='=' read -r key value; do
    case $key in
        dir_ok) dir_ok=$value ;;
        nvim_ok) nvim_ok=$value ;;
        term_ok) term_ok=$value ;;
        entries) entries=$value ;;
    esac
done <<< "$probe"

[ "$nvim_ok" = 1 ] || die "no nvim in container $cid" \
    'the devcontainer image has to install it -- see .devcontainer/Dockerfile'

if [ "$dir_ok" != 1 ]; then
    # A workspace folder named differently from the host folder is common
    # enough (workspaceFolder in devcontainer.json, a renamed clone). With a
    # single candidate in /workspaces there is nothing to guess.
    # An array, not the positional parameters: those still hold the nvim args.
    read -r -a ws <<< "$entries"
    if [ -z "${dir:-}" ] && [ ${#ws[@]} -eq 1 ]; then
        workdir="/workspaces/${ws[0]}"
    elif [ ${#ws[@]} -gt 0 ]; then
        die "$workdir does not exist in the container" \
            "/workspaces holds: ${ws[*]}" 'pick one with --dir'
    else
        die "$workdir does not exist in the container" \
            '/workspaces is empty' 'pick a directory with --dir'
    fi
fi

term=${TERM:-xterm-256color}
if [ "$term_ok" != 1 ]; then
    warn "the container has no terminfo for TERM=$term, using xterm-256color"
    term=xterm-256color
fi

# -t only when we have a terminal, so the script stays usable from a pipe or
# a hook (`... -- --headless +... +qa`).
tty_flag=(-i)
[ -t 0 ] && [ -t 1 ] && tty_flag=(-i -t)

exec docker exec "${tty_flag[@]}" -u "$user" -w "$workdir" \
    -e TERM="$term" -e COLORTERM="${COLORTERM:-truecolor}" \
    "$cid" nvim "$@"
