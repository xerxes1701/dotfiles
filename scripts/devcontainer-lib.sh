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
# knows -- four details nobody wants to repeat on the command line. A
# container that is merely stopped counts as a candidate too and is started
# before the tool runs: VS Code shuts a devcontainer down with the last window
# on it, and a reboot leaves every one of them behind, so "not running right
# now" is a thing to fix rather than a reason to refuse.
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

# Container rows are tab-separated and one of the fields is a status like
# "Exited (0) 3 days ago", so the separator has to be spelled out wherever a
# row is built or split -- a bare space would cut that field in half.
dc_tab=$'\t'

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
  -c, --container NAME  container name or id, running or not -- a stopped
                        one is started. default: the only running
                        devcontainer; with several to choose from the script
                        asks, defaulting to the one whose workspace holds the
                        current directory. with no container at all the
                        devcontainer images are offered too, and building one
                        into a container is what picking it does.
  -u, --user NAME       user to run as. default: the container's remoteUser.
  -d, --dir DIR         directory to start in. absolute, or relative to
                        /workspaces. default: the workspace folder of the
                        chosen container.
  -w, --workspace PATH  host folder to build a container for, when an image
                        was picked and no container exists yet. default:
                        worked out from the workspaces seen before.
  -l, --list            list containers and images to choose from, and exit.
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

# --- discovery -------------------------------------------------------------
#
# Containers and images are offered side by side, as one list of things that
# could be worked in, in the order of what it costs to get there: a running
# container, a stopped one to start, an image to build a container from.
#
# Every row is kind<TAB>id<TAB>name<TAB>state<TAB>status<TAB>folder.
#   kind    container or image -- what picking the row will have to do
#   state   the one word docker settles on (running, exited, paused, ...),
#           or "image"; this is what the code branches on
#   status  its sentence about it ("Up 2 hours", "Exited (0) 3 days ago"),
#           which is what a person is shown instead
#   folder  the host workspace folder, and the one field that can be empty:
#           an image does not always say where it came from

# A devcontainer is any container labeled with the host folder it was started
# from, stopped ones included. Running ones come first, because one of those is
# nearly always what was meant.
dc_list_containers() {
    docker ps -a --filter 'label=devcontainer.local_folder' --format \
        "{{.ID}}$dc_tab{{.Names}}$dc_tab{{.State}}$dc_tab{{.Status}}$dc_tab{{.Label \"devcontainer.local_folder\"}}" \
        | awk -F'\t' -v OFS='\t' '
            { $0 = "container" OFS $0 }
            $4 == "running" { print; next }
            { stopped = stopped $0 "\n" }
            END { printf "%s", stopped }'
}

# An image built for a workspace is named vsc-<folder>-<64 hex>, and once the
# uid of the remote user has been fixed there is a -uid twin of it. Both are
# the same build, so only the first of the pair is offered.
#
# The folder name in the middle of that name is everything the image says about
# where it came from: devcontainer.local_folder is put on containers, never on
# images, so an image on its own does not know its own workspace. Hence
# dc_resolve_workspace, and hence the question when that comes up empty.
dc_list_images() {
    local id repo name folder seen=$dc_tab
    while IFS=$dc_tab read -r id repo; do
        name=${repo#vsc-}
        name=${name%-uid}
        [[ $name =~ ^(.+)-[0-9a-f]{64}$ ]] && name=${BASH_REMATCH[1]}
        case $seen in *"$dc_tab$name$dc_tab"*) continue ;; esac
        seen="$seen$name$dc_tab"
        folder=$(dc_resolve_workspace "$name")
        printf '%s\n' "image$dc_tab$id$dc_tab$name${dc_tab}image${dc_tab}image, no container yet$dc_tab$folder"
    done < <(docker images --filter 'reference=vsc-*' \
        --format "{{.ID}}$dc_tab{{.Repository}}" | sort -u -t"$dc_tab" -k2,2)
}

dc_list_candidates() {
    dc_list_containers
    dc_list_images
}

# --- remembering where workspaces are --------------------------------------

# Only a container carries devcontainer.local_folder, so the moment a container
# is gone -- rebuilt, pruned, removed after a config change -- its image is left
# knowing nothing about the folder it was built for. The folders are therefore
# written down as they are seen, and that list is what later turns an image
# back into something `devcontainer up` can be pointed at.
dc_cache=${XDG_STATE_HOME:-$HOME/.local/state}/devcontainer-launcher/workspaces

# dc_normalize_path is for comparing and flattens case to do it; this one is
# for using, so it converts the drive letter and the backslashes and then keeps
# its hands off. /mnt is case-sensitive even when the drive behind it is not.
dc_host_path() {
    printf '%s' "$1" | sed -E 's#\\#/#g; s#^([A-Za-z]):/#/mnt/\L\1\E/#; s#/+$##'
}

dc_cache_remember() {
    local folder
    folder=$(dc_host_path "${1:-}")
    [ -n "$folder" ] && [ -d "$folder" ] || return 0
    ! grep -qxF "$folder" "$dc_cache" 2>/dev/null || return 0
    mkdir -p "${dc_cache%/*}" 2>/dev/null \
        && printf '%s\n' "$folder" >> "$dc_cache" 2>/dev/null
    return 0
}

# Where an image's workspace is, worked out without asking or not at all. The
# remembered folders are exact and come first. After them comes the one guess
# worth making: worktrees of a project sit next to each other, so a sibling of
# a folder already seen, carrying a .devcontainer of its own, is almost
# certainly it. Everything past that is a question for the user.
dc_resolve_workspace() {
    local name=${1:-} seen
    [ -n "$name" ] || return 0
    if [ -f "$dc_cache" ]; then
        while IFS= read -r seen; do
            if [ "${seen##*/}" = "$name" ] && [ -d "$seen" ]; then
                printf '%s' "$seen"; return 0
            fi
        done < "$dc_cache"
        while IFS= read -r seen; do
            if [ -d "${seen%/*}/$name/.devcontainer" ]; then
                printf '%s' "${seen%/*}/$name"; return 0
            fi
        done < "$dc_cache"
    fi
    if [ "${PWD##*/}" = "$name" ] && [ -d "$PWD/.devcontainer" ]; then
        printf '%s' "$PWD"
    fi
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
    dc_container='' dc_user='' dc_dir='' dc_workspace='' dc_list=0
    while [ $# -gt 0 ]; do
        case $1 in
            -c|--container) dc_need_value "$1" "${2:-}"; dc_container=$2; shift 2 ;;
            --container=*)  dc_container=${1#*=}; dc_need_value --container "$dc_container"; shift ;;
            -u|--user)      dc_need_value "$1" "${2:-}"; dc_user=$2; shift 2 ;;
            --user=*)       dc_user=${1#*=}; dc_need_value --user "$dc_user"; shift ;;
            -d|--dir)       dc_need_value "$1" "${2:-}"; dc_dir=$2; shift 2 ;;
            --dir=*)        dc_dir=${1#*=}; dc_need_value --dir "$dc_dir"; shift ;;
            -w|--workspace) dc_need_value "$1" "${2:-}"; dc_workspace=$2; shift 2 ;;
            --workspace=*)  dc_workspace=${1#*=}; dc_need_value --workspace "$dc_workspace"; shift ;;
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

# The state column is for the script, not for a reader -- the status sentence
# next to it already says "Up 2 hours" or "Exited (0) 3 days ago" -- so drop it
# on the way to the table, and say so where a folder is not known rather than
# leaving a column blank.
dc_print_list() {
    local found
    found=$(dc_list_candidates)
    [ -n "$found" ] || die 'no devcontainer and no devcontainer image' \
        'start one in VS Code, or run `devcontainer up`'
    {
        printf '%sKIND\tID\tNAME\tSTATUS\tHOST FOLDER%s\n' "$o_bold" "$o_off"
        printf '%s\n' "$found" \
            | awk -F'\t' -v OFS='\t' '{ print $1, $2, $3, $5, ($6 == "" ? "(not known)" : $6) }'
    } | column -t -s "$dc_tab"
}

# --- pick the container ----------------------------------------------------

dc_pick_container() {
    dc_local_folder='' dc_state='' dc_kind=container dc_name=''

    if [ -n "$dc_container" ]; then
        # One inspect for both answers, and its failure is the existence
        # check: a name that matches nothing is a typo worth saying so about.
        local named
        named=$(docker inspect \
            --format "{{.State.Status}}$dc_tab{{index .Config.Labels \"devcontainer.local_folder\"}}" \
            "$dc_container" 2>/dev/null) \
            || die "no container named \"$dc_container\"" "run $self --list to see what there is"
        dc_cid=$dc_container
        dc_name=$dc_container
        IFS=$dc_tab read -r dc_state dc_local_folder <<< "$named"
        dc_cache_remember "$dc_local_folder"
        return
    fi

    local candidates chosen n_all n_running
    candidates=$(dc_list_candidates)
    [ -n "$candidates" ] || die 'no devcontainer and no devcontainer image' \
        'start one in VS Code, or run `devcontainer up`'
    n_all=$(printf '%s\n' "$candidates" | awk 'END { print NR }')
    n_running=$(printf '%s\n' "$candidates" | awk -F'\t' '$4 == "running" { n++ } END { print n + 0 }')

    if [ "$n_running" = 1 ]; then
        # Exactly one running container is the answer it has always been.
        # Stopped leftovers and old images -- and there are always stopped
        # leftovers and old images -- must not turn that into a question.
        chosen=$(printf '%s\n' "$candidates" | awk -F'\t' '$4 == "running"')
    elif [ "$n_all" = 1 ] && [ "${candidates%%$dc_tab*}" = container ]; then
        chosen=$candidates
    else
        # Sets dc_row rather than printing it: a `die` inside a command
        # substitution exits only the subshell, and the script would carry on
        # with an empty container id. A lone image goes through here too,
        # rather than down the branch above: building a container is a bigger
        # thing to have happen than starting one, and should be asked for.
        dc_ask_which "$candidates"
        chosen=$dc_row
    fi

    IFS=$dc_tab read -r dc_kind dc_cid dc_name dc_state _ dc_local_folder <<< "$chosen"
    [ "$dc_kind" = container ] && dc_cache_remember "$dc_local_folder"
    return 0
}

# More than one to choose from: the choice is the user's. The workspace that
# contains $PWD is offered as the default, because that is nearly always the
# one meant -- offered, not taken silently -- and a running container wins the
# default over a stopped one, since picking it costs nothing. Stopped rows are
# dimmed but on the list: choosing one is how you start it. The menu and the
# prompt go to stderr; the picked row lands in dc_row.
dc_ask_which() {
    local here kinds=() ids=() names=() states=() statuses=() folders=()
    local default=0 pwd_running=0 pwd_stopped=0 first_running=0 why=''
    local kind id name state status folder shown i n prompt choice
    here=$(dc_normalize_path "$PWD")
    while IFS=$dc_tab read -r kind id name state status folder; do
        kinds+=("$kind"); ids+=("$id"); names+=("$name"); states+=("$state")
        statuses+=("$status"); folders+=("$folder")
        i=${#ids[@]}
        if [ "$state" = running ] && [ "$first_running" = 0 ]; then
            first_running=$i
        fi
        # An empty folder would turn the pattern below into a bare /*, which
        # matches every absolute path there is. Images are not default
        # material anyway: they are the row that costs a build.
        [ "$kind" = container ] && [ -n "$folder" ] || continue
        case "$here/" in
            "$(dc_normalize_path "$folder")"/*)
                if [ "$state" = running ]; then
                    [ "$pwd_running" = 0 ] && pwd_running=$i
                else
                    [ "$pwd_stopped" = 0 ] && pwd_stopped=$i
                fi
                ;;
        esac
    done <<< "$1"
    n=${#ids[@]}

    if [ "$pwd_running" != 0 ]; then
        default=$pwd_running why='holds the current directory'
    elif [ "$pwd_stopped" != 0 ]; then
        default=$pwd_stopped why='holds the current directory'
    elif [ "$first_running" != 0 ]; then
        default=$first_running why='the one running'
    fi

    [ -t 0 ] && [ -t 2 ] || {
        warn 'several devcontainers to choose from:'
        printf '%s\n' "$1" \
            | awk -F'\t' -v OFS='\t' '{ print $1, $2, $3, $5, ($6 == "" ? "(not known)" : $6) }' \
            | column -t -s "$dc_tab" | sed 's/^/  /' >&2
        die 'no terminal to ask on' \
            "name one with --container, or run $self --list"
    }

    note 'several devcontainers to choose from:'
    for ((i = 1; i <= n; i++)); do
        shown=${folders[i-1]:-(workspace not known, you will be asked)}
        if [ "$i" = "$default" ]; then
            printf '%s* %d) %-20s %-26s %s%s\n' "$e_bold" "$i" \
                "${names[i-1]}" "${statuses[i-1]}" "$shown" "$e_off" >&2
        elif [ "${states[i-1]}" = running ]; then
            printf '  %d) %-20s %-26s %s\n' "$i" \
                "${names[i-1]}" "${statuses[i-1]}" "$shown" >&2
        else
            printf '%s  %d) %-20s %-26s %s%s\n' "$e_dim" "$i" \
                "${names[i-1]}" "${statuses[i-1]}" "$shown" "$e_off" >&2
        fi
    done
    prompt="which one? [1-$n]"
    [ "$default" != 0 ] && prompt="$prompt, default $default ($why)"
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
    dc_row="${kinds[choice-1]}	${ids[choice-1]}	${names[choice-1]}	${states[choice-1]}	${statuses[choice-1]}	${folders[choice-1]}"
}

# --- have it running -------------------------------------------------------

# Whatever was picked still has to be up before anything can be run in it.
# `docker start` brings the image's own command back, and that is all it
# brings: the lifecycle hooks in devcontainer.json -- postStartCommand and
# friends -- belong to VS Code and the devcontainer CLI, so a workspace that
# needs one of them to be usable will not be, and saying so once beats a
# puzzling tool five seconds later.
dc_ensure_running() {
    if [ "$dc_kind" = image ]; then
        dc_create_from_image
        return
    fi
    case $dc_state in
        running)
            return 0 ;;
        paused)
            note "container $dc_cid is paused -- unpausing it"
            docker unpause "$dc_cid" >/dev/null \
                || die "cannot unpause container $dc_cid" ;;
        created|exited)
            note "container $dc_cid is $dc_state -- starting it"
            docker start "$dc_cid" >/dev/null || dc_die_unstartable
            warn 'postStartCommand and the other devcontainer.json lifecycle hooks do not run on `docker start`' ;;
        restarting)
            note "container $dc_cid is restarting -- waiting for it" ;;
        *)
            die "container $dc_cid is $dc_state, which this script cannot undo" \
                'open it in VS Code, or run `devcontainer up`' ;;
    esac
    dc_wait_running
}

# A container that refuses to start has usually been overtaken by its own
# devcontainer.json: mounts are fixed when the container is created, so a
# source path that moved or was renamed since then is gone for good as far as
# this container is concerned, and no amount of starting will pick the new
# config up. Docker says which path it is; what it does not say is that a
# rebuild is the only way out -- and that `docker logs` is the wrong place to
# look, since it only ever shows the run before this one.
dc_die_unstartable() {
    local source missing=()
    while IFS= read -r source; do
        if [ -n "$source" ] && [ ! -e "$source" ]; then missing+=("$source"); fi
    done < <(docker inspect --format \
        '{{range .Mounts}}{{if eq .Type "bind"}}{{.Source}}{{"\n"}}{{end}}{{end}}' \
        "$dc_cid" 2>/dev/null)

    [ ${#missing[@]} -eq 0 ] || die \
        "container $dc_cid is built on host paths that no longer exist" \
        "${missing[@]/#/gone: }" \
        'mounts are fixed when a container is created, so devcontainer.json has moved on without it' \
        'rebuild it: "Dev Containers: Rebuild Container" in VS Code, or `devcontainer up`'
    die "cannot start container $dc_cid" \
        'rebuild it: "Dev Containers: Rebuild Container" in VS Code, or `devcontainer up`'
}

# `docker start` returns once the container has been started, which is not the
# same as it staying up: a container whose command exits immediately is back to
# "exited" a moment later, and the docker exec after it fails with an error
# that never mentions the reason. Five seconds is generous for a devcontainer,
# whose command is usually `sleep infinity`.
dc_wait_running() {
    local i state=''
    for ((i = 0; i < 50; i++)); do
        state=$(docker inspect --format '{{.State.Status}}' "$dc_cid" 2>/dev/null) || state=gone
        case $state in
            running)    dc_state=running; return 0 ;;
            restarting) sleep 0.1 ;;
            *)          break ;;
        esac
    done
    die "container $dc_cid did not come up -- it is $state" \
        "docker logs $dc_cid may say why" \
        'opening it in VS Code rebuilds it properly'
}

# --- build a container out of an image -------------------------------------

# Creating a container is `devcontainer up` and deliberately not `docker run`.
# Everything that makes a devcontainer usable -- the workspace mount, the
# sibling repository this project needs, the ssh directory, the named volumes,
# the remote user, the lifecycle hooks -- is written in devcontainer.json and
# nowhere else. A hand-rolled `docker run` from the image would come up without
# any of it and look almost right, which is the worst way for it to be wrong.
#
# The cost is the workspace folder: the CLI needs the host path, and the image
# only knows the name of the folder. dc_resolve_workspace tries, --workspace
# says outright, and failing both there is a question.
dc_create_from_image() {
    local folder=${dc_workspace:-$dc_local_folder}

    [ -n "$folder" ] || { dc_ask_workspace; folder=$dc_workspace; }
    folder=$(dc_host_path "$folder")

    [ -d "$folder" ] || die "no such directory: $folder" \
        'name the workspace folder with --workspace PATH'
    [ -f "$folder/.devcontainer/devcontainer.json" ] \
        || die "$folder holds no .devcontainer/devcontainer.json" \
            'the image was built from one, so this is likely the wrong folder' \
            'name the right one with --workspace PATH'

    command -v devcontainer >/dev/null \
        || die 'the devcontainer CLI is not installed' \
            'npm install -g @devcontainers/cli' \
            'or open the folder in VS Code, which builds the container itself'

    note "no container for $dc_name yet -- building one from $folder"
    warn 'VS Code labels its containers with the windows path of the workspace and the CLI in here labels them with the wsl path, so VS Code will not adopt this container -- it will build a second one next to it'

    # Its own output is the progress report, and a build is not quick. Onto
    # stderr, because stdout belongs to the tool this script exists to run.
    devcontainer up --workspace-folder "$folder" >&2 \
        || die "devcontainer up failed for $folder" 'its output above says why'

    dc_find_by_folder "$folder" \
        || die 'devcontainer up reported success but left no container labelled for that folder' \
            "run $self --list to see what there is"
    dc_kind=container
    dc_cache_remember "$folder"
    dc_ensure_running
}

# The container the CLI has just made, found the way every other one is found.
# dc_list_containers puts running first, so the first match is the live one.
dc_find_by_folder() {
    local want kind id name state status folder
    want=$(dc_normalize_path "$1")
    while IFS=$dc_tab read -r kind id name state status folder; do
        [ "$(dc_normalize_path "$folder")" = "$want" ] || continue
        dc_cid=$id dc_name=$name dc_state=$state dc_local_folder=$folder
        return 0
    done < <(dc_list_containers)
    return 1
}

# Sets dc_workspace rather than printing it, for the same reason dc_ask_which
# sets dc_row: a `die` inside a command substitution would exit the subshell
# and let the script carry on with an empty answer.
dc_ask_workspace() {
    local answer
    [ -t 0 ] && [ -t 2 ] || die "cannot tell where the workspace \"$dc_name\" is" \
        'an image carries no devcontainer.local_folder -- its name is all there is' \
        'name the folder with --workspace PATH'
    note "the image is named for a workspace called \"$dc_name\", but does not say where it is"
    printf '%spath to it: %s' "$e_cyan" "$e_off" >&2
    read -r answer || { printf '\n' >&2; die 'nothing given'; }
    [ -n "$answer" ] || die 'nothing given'
    case $answer in
        '~')   answer=$HOME ;;
        '~/'*) answer=$HOME/${answer#\~/} ;;
    esac
    dc_workspace=$answer
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
    if [ "$term_ok" != 1 ] && [ "$dc_term" != xterm-256color ]; then
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
    dc_ensure_running
    dc_pick_user
    dc_pick_workdir
    dc_exec
}
