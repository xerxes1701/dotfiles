# Shared logic of the devcontainer-<tool>.sh launchers. Sourced, never run.
#
# A launcher describes its tool and hands over:
#
#   . "$(dirname -- "$(readlink -f -- "$0")")/devcontainer-lib.sh"
#   dc_tool=nvim
#   dc_tool_hint='the devcontainer image has to install it'
#   dc_examples=("\$self README.md" "\$self -- --headless +qa")
#   dc_main "$@"
#
# Everything the launchers have in common lives here: which container, which
# user, which /workspaces folder, and a TERM the container's terminfo actually
# knows -- four details nobody wants to repeat on the command line.
#
# It talks to docker directly rather than through `devcontainer exec`, because
# the CLI re-resolves devcontainer.json on every call (seconds), and because it
# matches containers by the host path it was given -- which never matches a
# container that VS Code on Windows started, whose devcontainer.local_folder
# label is a Windows path.

# Sourcing is the only supported use: on its own this file knows no tool to run.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    printf 'devcontainer-lib.sh is a library. Run devcontainer-nvim.sh or devcontainer-herdr.sh.\n' >&2
    exit 1
fi

self=$(basename -- "$0")

# --- output ----------------------------------------------------------------

# Colors only for a terminal, and never against NO_COLOR (https://no-color.org)
# or TERM=dumb. Diagnostics go to stderr, the --list table to stdout, so the
# two streams get their own decision.
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

dc_usage() {
    printf '%susage:%s %s [options] [--] [%s args...]\n\n' \
        "$o_bold" "$o_off" "$self" "$dc_tool"
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

Arguments after the options go to $dc_tool unchanged and are resolved inside
the container, relative to the start directory -- a host path is not
translated. Put \`--\` before any $dc_tool argument that starts with a dash,
so that this script does not read it as one of its own:
EOF
    printf '\n'
    local example
    for example in ${dc_examples[@]+"${dc_examples[@]}"}; do
        printf '  %s\n' "$example"
    done
}

# --- container discovery ---------------------------------------------------

# A devcontainer is any container labeled with the host folder it was started
# from. Format: id<TAB>name<TAB>local_folder.
dc_list_containers() {
    docker ps --filter 'label=devcontainer.local_folder' \
        --format '{{.ID}}	{{.Names}}	{{.Label "devcontainer.local_folder"}}'
}

# Compare host paths across the WSL/Windows divide: VS Code on Windows labels
# the container "c:\SWProjekte\firstx-master", while the same directory is
# /mnt/c/SWProjekte/firstx-master in here. Lowercase, forward slashes, drive
# letter turned into a /mnt mount point.
dc_normalize_path() {
    printf '%s' "$1" \
        | tr 'A-Z\\' 'a-z/' \
        | sed -E 's#^([a-z]):/#/mnt/\1/#; s#/+$##'
}

# --- options ---------------------------------------------------------------

dc_need_value() {
    [ -n "$2" ] || die "option $1 needs a value" "see $self --help"
}

# Long and short forms both, --opt=value included. getopts would cover only
# the short ones. What is left over is the tool's own argument list.
dc_parse_args() {
    dc_container='' dc_user='' dc_dir='' dc_list=0
    while [ $# -gt 0 ]; do
        case $1 in
            -c|--container) dc_need_value "$1" "${2:-}"; dc_container=$2; shift 2 ;;
            --container=*)  dc_container=${1#*=}; dc_need_value --container "$dc_container"; shift ;;
            -u|--user)      dc_need_value "$1" "${2:-}"; dc_user=$2; shift 2 ;;
            --user=*)       dc_user=${1#*=}; dc_need_value --user "$dc_user"; shift ;;
            -d|--dir)       dc_need_value "$1" "${2:-}"; dc_dir=$2; shift 2 ;;
            --dir=*)        dc_dir=${1#*=}; dc_need_value --dir "$dc_dir"; shift ;;
            -l|--list)      dc_list=1; shift ;;
            -h|--help)      dc_usage; exit 0 ;;
            --)             shift; break ;;
            -?*)            die "unknown option $1" \
                                "arguments for $dc_tool itself go after --, e.g. $self -- $1" \
                                "see $self --help" ;;
            *)              break ;;
        esac
    done
    dc_args=("$@")
}

dc_print_list() {
    local found
    found=$(dc_list_containers)
    [ -n "$found" ] || die 'no running devcontainer' 'start it in VS Code, or run `devcontainer up`'
    printf '%sCONTAINER ID\tNAME\tHOST FOLDER%s\n%s\n' "$o_bold" "$o_off" "$found" \
        | column -t -s "$(printf '\t')"
}

# --- pick the container ----------------------------------------------------

dc_pick_container() {
    dc_local_folder=''

    if [ -n "$dc_container" ]; then
        docker inspect --format '{{.State.Running}}' "$dc_container" 2>/dev/null | grep -qx true \
            || die "container \"$dc_container\" is not running" "run $self --list to see what is"
        dc_cid=$dc_container
        dc_local_folder=$(docker inspect \
            --format '{{index .Config.Labels "devcontainer.local_folder"}}' "$dc_cid" 2>/dev/null)
        return
    fi

    local candidates
    candidates=$(dc_list_containers)
    [ -n "$candidates" ] \
        || die 'no running devcontainer' 'start it in VS Code, or run `devcontainer up`'

    if [ "$(printf '%s\n' "$candidates" | wc -l)" -gt 1 ]; then
        # Sets dc_row rather than printing it: a `die` inside a command
        # substitution exits only the subshell, and the script would carry on
        # with an empty container id.
        dc_ask_which "$candidates"
        candidates=$dc_row
    fi

    IFS=$'\t' read -r dc_cid _ dc_local_folder <<< "$candidates"
}

# More than one running: the choice is the user's. The workspace that contains
# $PWD is offered as the default, because that is nearly always the one meant
# -- offered, not taken silently. The menu and the prompt go to stderr; the
# picked id<TAB>name<TAB>folder row lands in dc_row.
dc_ask_which() {
    local here ids=() names=() folders=() default=0 id name folder i n prompt choice
    here=$(dc_normalize_path "$PWD")
    while IFS=$'\t' read -r id name folder; do
        ids+=("$id"); names+=("$name"); folders+=("$folder")
        case "$here/" in
            "$(dc_normalize_path "$folder")"/*) default=${#ids[@]} ;;
        esac
    done <<< "$1"
    n=${#ids[@]}

    [ -t 0 ] && [ -t 2 ] || {
        warn 'several devcontainers are running:'
        printf '%s\n' "$1" | sed 's/^/  /' >&2
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
    dc_row="${ids[choice-1]}	${names[choice-1]}	${folders[choice-1]}"
}

# --- pick the user ---------------------------------------------------------

# The image itself runs as root; the user to become is in the devcontainer
# metadata label, which is a JSON array of merged config fragments. The last
# remoteUser in it is the effective one.
dc_pick_user() {
    [ -z "$dc_user" ] || return 0
    local metadata
    metadata=$(docker inspect \
        --format '{{index .Config.Labels "devcontainer.metadata"}}' "$dc_cid" 2>/dev/null)
    if command -v jq >/dev/null; then
        dc_user=$(printf '%s' "$metadata" \
            | jq -r '[.[]? | .remoteUser // empty] | last // empty' 2>/dev/null)
    else
        dc_user=$(printf '%s' "$metadata" \
            | grep -o '"remoteUser"[[:space:]]*:[[:space:]]*"[^"]*"' \
            | tail -n1 | sed 's/.*"\([^"]*\)"$/\1/')
    fi
    [ -n "$dc_user" ] || dc_user=root
}

# --- pick the directory, and check the container can do the job ------------

dc_pick_workdir() {
    case $dc_dir in
        '')   dc_workdir="/workspaces/$(basename -- \
                  "$(printf '%s' "$dc_local_folder" | tr '\\' '/' | sed 's#/*$##')")" ;;
        /*)   dc_workdir=$dc_dir ;;
        *)    dc_workdir="/workspaces/$dc_dir" ;;
    esac

    # One round trip for everything that has to be true in there: the directory
    # exists, the tool is installed, and the container knows our TERM. A
    # terminfo the container lacks (ghostty, wezterm) leaves a full-screen tool
    # with a crippled or unusable display, and what it prints about that never
    # says TERM is the reason.
    local probe dir_ok=0 tool_ok=0 term_ok=0 entries='' key value ws
    probe=$(docker exec -e PROBE_DIR="$dc_workdir" -e PROBE_TERM="${TERM:-}" \
        -e PROBE_TOOL="$dc_tool" "$dc_cid" sh -c '
        [ -d "$PROBE_DIR" ] && echo dir_ok=1 || echo dir_ok=0
        command -v "$PROBE_TOOL" >/dev/null && echo tool_ok=1 || echo tool_ok=0
        [ -n "$PROBE_TERM" ] && infocmp "$PROBE_TERM" >/dev/null 2>&1 && echo term_ok=1 || echo term_ok=0
        echo "entries=$(ls -1 /workspaces 2>/dev/null | tr "\n" " ")"
    ') || die "cannot run a command in container $dc_cid" 'is it still running?'

    while IFS='=' read -r key value; do
        case $key in
            dir_ok)  dir_ok=$value ;;
            tool_ok) tool_ok=$value ;;
            term_ok) term_ok=$value ;;
            entries) entries=$value ;;
        esac
    done <<< "$probe"

    [ "$tool_ok" = 1 ] || die "no $dc_tool in container $dc_cid" \
        "${dc_tool_hint:-the devcontainer image has to install it}"

    if [ "$dir_ok" != 1 ]; then
        # A workspace folder named differently from the host folder is common
        # enough (workspaceFolder in devcontainer.json, a renamed clone). With
        # a single candidate in /workspaces there is nothing to guess.
        read -r -a ws <<< "$entries"
        if [ -z "$dc_dir" ] && [ ${#ws[@]} -eq 1 ]; then
            dc_workdir="/workspaces/${ws[0]}"
        elif [ ${#ws[@]} -gt 0 ]; then
            die "$dc_workdir does not exist in the container" \
                "/workspaces holds: ${ws[*]}" 'pick one with --dir'
        else
            die "$dc_workdir does not exist in the container" \
                '/workspaces is empty' 'pick a directory with --dir'
        fi
    fi

    dc_term=${TERM:-xterm-256color}
    if [ "$term_ok" != 1 ]; then
        warn "the container has no terminfo for TERM=$dc_term, using xterm-256color"
        dc_term=xterm-256color
    fi
}

# --- run -------------------------------------------------------------------

dc_exec() {
    # -t only when we have a terminal, so a launcher stays usable from a pipe
    # or a hook (`... -- --headless +... +qa`).
    local tty_flag=(-i)
    [ -t 0 ] && [ -t 1 ] && tty_flag=(-i -t)

    exec docker exec "${tty_flag[@]}" -u "$dc_user" -w "$dc_workdir" \
        -e TERM="$dc_term" -e COLORTERM="${COLORTERM:-truecolor}" \
        "$dc_cid" "$dc_tool" ${dc_args[@]+"${dc_args[@]}"}
}

dc_main() {
    [ -n "${dc_tool:-}" ] || die 'internal error: dc_tool is not set' \
        'a launcher has to set dc_tool before calling dc_main'
    dc_parse_args "$@"
    command -v docker >/dev/null \
        || die 'docker is not on PATH' 'this script runs on the host, not inside the container'
    if [ "$dc_list" = 1 ]; then
        dc_print_list
        exit 0
    fi
    dc_pick_container
    dc_pick_user
    dc_pick_workdir
    dc_exec
}
