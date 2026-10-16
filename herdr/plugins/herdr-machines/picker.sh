#!/usr/bin/env bash
# The devcontainers behind herdr's saved machines, in a list. Pick one or
# several and they come up in order: Docker Desktop first if it is down, then
# the container (rebuilt first if it is gone and you agree), then herdr's
# connection to it.
#
# A saved machine counts as a devcontainer when its ssh target resolves to a
# port on this machine's loopback. Its container is the one that publishes
# that port. Both come from what is already there, so there is no table of
# machines to keep up to date: `ssh -G` resolves the target, and docker keeps
# a container's port bindings even while it is stopped. Any other machine
# (HAL-Laptop) is left off the list, since there is nothing here to start for
# it.
#
# In the list, enter brings the marked machines up: a stopped container is
# started, a running one left alone. ctrl-r restarts them instead, running or
# not, and ctrl-alt-r rebuilds them with devcontainer-rebuild.sh, as VS Code's
# Rebuild Container does. Both end every agent inside, so they are keys you
# have to choose; neither asks again. (Not ctrl-shift-r: a terminal sends that
# as the same byte as ctrl-r, and fzf could not tell them apart.)
#
# A herdr popup is modal: while it is open, nothing else in herdr takes a key.
# So the work does not run in the popup. It runs as a job of its own, detached
# from it, and the popup only follows the job's log:
#
#   esc     closes the popup and leaves the job running. The same key that
#           opened the list brings it back while the job runs.
#   ctrl-c  cancels the job, and everything it started.
#   y / n   answers the job's question, when it has one (whether to rebuild).
#   p       copies the log to the clipboard: text in a popup cannot be selected.
#   P       copies the log's path instead.
#
# Those keys stay on the popup's last line.
#
# A job that ends while nobody watches says so in a herdr notification. Each
# run's log is kept under the plugin's state directory, the last 20 of them.
#
# Runs as the plugin's popup pane; `bash picker.sh` from a shell works as well.
# `picker.sh --job ...` is the job itself, started by the picker.

set -u

herdr=${HERDR_BIN_PATH:-herdr}
docker_exe='/mnt/c/Program Files/Docker/Docker/resources/bin/docker.exe'
self=$(readlink -f -- "$0")

e_off=$'\e[0m' e_dim=$'\e[2m' e_red=$'\e[31m' e_green=$'\e[32m' e_yellow=$'\e[33m' e_cyan=$'\e[36m'
failed=0
say() { printf '%s%s%s\n' "$1" "$2" "$e_off"; }
note() { say "$e_cyan" "$*"; }
warn() { say "$e_yellow" "$*"; }
fail() { say "$e_red" "$*"; failed=1; }
ok()   { say "$e_green" "$*"; }

# The job's files. job.pid names the running job, which leads a process group
# of its own; current.log is its log; question and answer carry the one thing
# it may need to ask; status is how it ended; viewer.pid is the popup
# following it, if one is.
state=${HERDR_PLUGIN_STATE_DIR:-$HOME/.local/state/herdr-machines}
logs=$state/logs
mkdir -p "$logs"
job_pid_file=$state/job.pid
current=$state/current.log
question_file=$state/question
answer_file=$state/answer
status_file=$state/status
viewer_pid_file=$state/viewer.pid
keep_logs=20

# The pid of the running job, or a failure. The command line is checked as
# well, since a pid left in the file may belong to anything by now.
job_running() {
    local pid
    pid=$(cat "$job_pid_file" 2>/dev/null) || return 1
    [ -n "$pid" ] && tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null | grep -q -- "--job" || return 1
    printf '%s\n' "$pid"
}

viewer_attached() {
    local pid
    pid=$(cat "$viewer_pid_file" 2>/dev/null) && [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}

# WSL's clipboard is Windows', reached through clip.exe; a Wayland session
# has its own. Copies stdin.
to_clipboard() {
    if [ -n "${WAYLAND_DISPLAY:-}" ] && command -v wl-copy >/dev/null; then
        wl-copy
    else
        clip.exe
    fi
}

# The log's text, without its colours, or its path.
copy_log() { sed 's/\x1b\[[0-9;]*m//g' "$current" | to_clipboard; }
copy_log_path() { readlink -f "$current" | tr -d '\n' | to_clipboard; }

# WSL's own docker is the cheaper of the two, but it is a symlink that only
# resolves while Docker Desktop runs. docker.exe is always there, and it is
# also what starts Docker Desktop.
docker() {
    if [ -x /usr/bin/docker ]; then /usr/bin/docker "$@"; else "$docker_exe" "$@"; fi
}
engine_up() { docker info --format '{{.ServerVersion}}' >/dev/null 2>&1; }

# Whether an sshd answers on the port, which is what herdr needs. A bare TCP
# connect would not do: Docker Desktop's port forwarder accepts the connection
# whether or not anything is listening behind it, so this reads the banner.
# `herdr machine status` would say it too, but takes ten seconds and more per
# unreachable machine.
sshd_answers() {
    timeout 2 bash -c 'exec 3<>"/dev/tcp/127.0.0.1/$1" && IFS= read -r -t 1 l <&3 && [[ $l == SSH-* ]]' \
        _ "$1" 2>/dev/null
}

# Each container, with its state and the host ports it publishes:
#   name <tab> state <tab> port port ...
containers() {
    local ids
    ids=$(docker ps -aq 2>/dev/null | tr -d '\r') || return 0
    [ -n "$ids" ] || return 0
    # shellcheck disable=SC2086 # one argument per id
    docker inspect --format \
        '{{slice .Name 1}}{{"\t"}}{{.State.Status}}{{"\t"}}{{range $p, $b := .HostConfig.PortBindings}}{{range $b}}{{.HostPort}} {{end}}{{end}}' \
        $ids 2>/dev/null | tr -d '\r'
}

# The container publishing the port, as "name <tab> state", or nothing.
container_on() {
    containers | awk -F '\t' -v port="$1" '
        { n = split($3, ports, " "); for (i = 1; i <= n; i++) if (ports[i] == port) { print $1 "\t" $2; exit } }'
}

# Saved machines whose target is a loopback port: id <tab> label <tab> port.
devcontainer_machines() {
    local id label target host port
    "$herdr" machine list --json | jq -r '.[] | select(.enabled) | [.id, .label, .target] | @tsv' |
        while IFS=$'\t' read -r id label target; do
            host=$(ssh -G "$target" 2>/dev/null | awk '$1 == "hostname" { print $2 }')
            port=$(ssh -G "$target" 2>/dev/null | awk '$1 == "port" { print $2 }')
            case $host in
                127.0.0.1 | localhost | ::1) printf '%s\t%s\t%s\n' "$id" "$label" "$port" ;;
            esac
        done
}

# The lines fzf shows: id, label and port for the script, then what you read.
picker_lines() {
    local id label port name state reach engine=1 all machines probes
    machines=$(devcontainer_machines)
    [ -n "$machines" ] || return 0
    # A closed port here does not refuse, it times out, so the probes run
    # side by side rather than one after another.
    probes=$(mktemp -d)
    while IFS=$'\t' read -r id label port; do
        { sshd_answers "$port" && touch "$probes/$port"; } &
    done <<<"$machines"
    engine_up || engine=0
    all=$([ $engine = 1 ] && containers)
    wait
    while IFS=$'\t' read -r id label port; do
        name=- state='docker down'
        if [ $engine = 1 ]; then
            read -r name state < <(printf '%s\n' "$all" | awk -F '\t' -v port="$port" '
                { n = split($3, ports, " "); for (i = 1; i <= n; i++) if (ports[i] == port) { print $1, $2; exit } }')
            [ -n "${name:-}" ] || { name=- state='no container'; }
        fi
        if [ -e "$probes/$port" ]; then reach="${e_green}sshd answers${e_off}"; else reach="${e_dim}no sshd${e_off}"; fi
        printf '%s\t%s\t%s\t%-12s %-36s %-14s %s\n' "$id" "$label" "$port" "$label" "$name" "$state" "$reach"
    done <<<"$machines"
    rm -rf "$probes"
}

ensure_engine() {
    engine_up && return 0
    note 'Docker Desktop is not running, starting it'
    "$docker_exe" desktop start --timeout 180 || { fail 'Docker Desktop did not start'; return 1; }
    local i
    for ((i = 0; i < 30; i++)); do
        engine_up && return 0
        sleep 1
    done
    fail 'Docker Desktop started, but its engine does not answer'
    return 1
}

# The compose service a devcontainer config runs as, and its compose files:
#   service <tab> file <tab> file ...
# Fails for a config that is not compose-based. devcontainer.json is JSONC, so
# comments and trailing commas come out before json reads it. Strings are
# copied whole, so a // inside one (a URL) survives.
compose_of() {
    python3 -I - "$1" <<'EOF'
import json, os, re, sys

path = sys.argv[1]
text = open(path, encoding="utf-8").read()
out, i, n = [], 0, len(text)
while i < n:
    if text[i] == '"':
        j = i + 1
        while j < n and text[j] != '"':
            j += 2 if text[j] == "\\" else 1
        out.append(text[i : j + 1])
        i = j + 1
    elif text.startswith("//", i):
        j = text.find("\n", i)
        i = n if j < 0 else j
    elif text.startswith("/*", i):
        j = text.find("*/", i)
        i = n if j < 0 else j + 2
    else:
        out.append(text[i])
        i += 1
cfg = json.loads(re.sub(r",(\s*[}\]])", r"\1", "".join(out)))

files, service = cfg.get("dockerComposeFile"), cfg.get("service")
if not files or not service:
    sys.exit(1)
if isinstance(files, str):
    files = [files]
base = os.path.dirname(path)
print("\t".join([service] + [os.path.normpath(os.path.join(base, f)) for f in files]))
EOF
}

# The devcontainer-rebuild.sh name (ActivityTracer/frontend) of the config
# whose compose service publishes the port. Once its container is gone, this
# is the only way back from a saved machine to its project. Fails when no
# config it knows of publishes the port.
config_for_port() {
    local port=$1 disp dir cfg name svc f
    local -a parts args
    while IFS=$'\t' read -r disp dir cfg name; do
        IFS=$'\t' read -r -a parts < <(compose_of "$cfg" 2>/dev/null) || continue
        [ ${#parts[@]} -ge 2 ] || continue
        svc=${parts[0]} args=()
        for f in "${parts[@]:1}"; do args+=(-f "$f"); done
        if docker compose "${args[@]}" config --format json 2>/dev/null |
            jq -e --arg s "$svc" --arg p "$port" \
                '.services[$s].ports[]? | select((.published | tostring) == $p)' >/dev/null; then
            printf '%s\n' "$name"
            return 0
        fi
    done < <(devcontainer-rebuild.sh --list-rows 2>/dev/null)
    return 1
}

# The job's one question, answered y or n from the popup. A job running in
# the background waits for it, and says so in a notification.
ask() {
    local answer
    rm -f "$answer_file"
    printf '%s\n' "$1" >"$question_file"
    say "$e_yellow" "  $1 [y/n]"
    viewer_attached ||
        "$herdr" notification show "herdr-machines has a question" \
            --body "$1 -- open it with prefix+shift+m" --sound request >/dev/null 2>&1
    until [ -s "$answer_file" ]; do sleep 0.3; done
    answer=$(cat "$answer_file")
    rm -f "$question_file" "$answer_file"
    say '' "  answered $answer"
    [ "$answer" = y ]
}

# Rebuilds the container behind a machine with devcontainer-rebuild.sh, the
# way VS Code would. Asks first unless "asked" is given: a container that is
# merely gone gets a question, a rebuild picked with its own key does not.
rebuild_for() {
    local label=$1 port=$2 asked=${3:-} config
    note "  looking for the devcontainer config that publishes port $port..."
    if ! config=$(config_for_port "$port"); then
        fail "  no devcontainer config that devcontainer-rebuild.sh knows publishes port $port"
        fail "  run devcontainer-rebuild.sh and pick the project there"
        return 1
    fi
    if [ -z "$asked" ]; then
        ask "rebuild $config for $label now?" || { fail "  not rebuilt"; return 1; }
    fi
    note "  rebuilding $config"
    devcontainer-rebuild.sh -y "$config" ||
        { fail "  rebuilding $config failed; devcontainer-rebuild.sh logs to ~/.local/state/devcontainer-rebuild"; return 1; }
    ok "  rebuilt"
}

# Brings up the container behind one machine -- mode is start, restart or
# rebuild; a container that is gone is rebuilt if you agree -- waits until its
# sshd answers, and then until herdr can reach it.
bring_up() {
    local id=$1 label=$2 port=$3 mode=$4 name state i
    printf '\n'
    note "$label (port $port)"
    IFS=$'\t' read -r name state < <(container_on "$port")
    if [ "$mode" = rebuild ] || [ -z "${name:-}" ]; then
        if [ "$mode" = rebuild ]; then
            rebuild_for "$label" "$port" asked || return
        else
            warn "  no container publishes port $port; it has been removed"
            rebuild_for "$label" "$port" || return
        fi
        IFS=$'\t' read -r name state < <(container_on "$port")
        if [ -z "${name:-}" ]; then
            fail "  still no container publishes port $port after the rebuild"
            return
        fi
        mode=start
    fi

    if [ "$mode" = restart ]; then
        note "  restarting $name ($state)"
        docker restart "$name" >/dev/null || { fail "  docker restart $name failed"; return; }
    else
        case $state in
            running) note "  $name is already running" ;;
            paused)
                note "  unpausing $name"
                docker unpause "$name" >/dev/null || { fail "  docker unpause $name failed"; return; } ;;
            created | exited | restarting)
                note "  starting $name ($state)"
                docker start "$name" >/dev/null || { fail "  docker start $name failed; docker logs $name may say why"; return; } ;;
            *)
                fail "  $name is $state, which docker start cannot undo"
                return ;;
        esac
    fi

    # `docker start` returns before the container's own command has had a
    # chance to exit again, so whether it stays up shows only afterwards.
    for ((i = 0; i < 60; i++)); do
        sshd_answers "$port" && break
        state=$(docker inspect --format '{{.State.Status}}' "$name" 2>/dev/null | tr -d '\r')
        if [ "$state" != running ] && [ "$state" != restarting ]; then
            fail "  $name stopped again ($state); docker logs $name may say why"
            return
        fi
        sleep 1
    done
    if ! sshd_answers "$port"; then
        # devcontainer.json's lifecycle hooks belong to VS Code and the
        # devcontainer CLI, not to docker, so an sshd that one of them starts
        # does not come back with `docker start`.
        fail "  $name runs, but no sshd answers on port $port after a minute."
        fail "  If a postStartCommand starts sshd, docker start skips it; open the project in VS Code"
        return
    fi
    ok "  sshd answers"

    # sshd answering is not yet herdr answering. In a container that was
    # just started, herdr is installed but its server is not running, and
    # `herdr machine status` calls that "stopped or incompatible". Nothing
    # here starts it: the open client does, on its next retry, which after
    # repeated failures is up to two minutes away. So this waits for that.
    local status='' error=''
    note "  waiting for the sidebar to connect (up to 2 min)"
    for ((i = 0; i < 75; i++)); do
        IFS=$'\t' read -r status error < <("$herdr" machine status "$id" --json 2>/dev/null |
            jq -r '.[0] | [.status, (.error // "")] | @tsv')
        case $status in
            reachable | auth*) break ;;
        esac
        sleep 2
    done
    case $status in
        reachable)
            ok "  $label is reachable" ;;
        auth*)
            # Authentication needs a terminal, ssh asks for the passphrase on
            # it, and the job has none.
            fail "  $label needs authentication: run herdr machine reconnect $label" ;;
        *)
            fail "  herdr still cannot reach $label: ${error:-$status}" ;;
    esac
}

# --- the job ----------------------------------------------------------------

# picker.sh --job <start|restart|rebuild> <id<tab>label<tab>port>...
run_job() {
    local mode=$1 line id label port
    shift
    printf '%s\n' "$$" >"$job_pid_file"
    rm -f "$status_file" "$question_file" "$answer_file"
    trap 'finish_job' EXIT
    # A cancel: the viewer that sent it reports it, so the exit says nothing.
    trap 'cancelled=1; exit 143' TERM
    ensure_engine || exit 1
    for line in "$@"; do
        IFS=$'\t' read -r id label port <<<"$line"
        bring_up "$id" "$label" "$port" "$mode"
    done
}

cancelled=0
finish_job() {
    local result=ok
    [ "$cancelled" = 0 ] || return 0
    [ "$failed" = 0 ] || result=failed
    printf '%s\n' "$result" >"$status_file"
    rm -f "$job_pid_file" "$question_file" "$answer_file"
    viewer_attached ||
        "$herdr" notification show "herdr-machines: $result" \
            --body "$(sed 's/\x1b\[[0-9;]*m//g' "$current" | tail -n 1)" \
            --sound "$([ $result = ok ] && echo done || echo request)" >/dev/null 2>&1
}

start_job() {
    local stamp log
    stamp=$(date +%Y%m%d-%H%M%S)
    log=$logs/run-$stamp.log
    : >"$log"
    ln -sfn "$log" "$current"
    # Keep the newest runs only.
    ls -1t "$logs"/run-*.log 2>/dev/null | tail -n +$((keep_logs + 1)) | xargs -r rm -f
    rm -f "$job_pid_file" "$status_file"
    # Its own session, so that it outlives the popup and a cancel can take
    # its whole process group, devcontainer builds included.
    setsid -f bash "$self" --job "$@" </dev/null >>"$log" 2>&1
    local i
    for ((i = 0; i < 50; i++)); do
        job_running >/dev/null && return 0
        sleep 0.1
    done
}

# --- the popup: following the job ------------------------------------------

cancel_job() {
    local pid
    pid=$(job_running) || return 0
    kill -TERM -- "-$pid" 2>/dev/null
    for ((i = 0; i < 30; i++)); do kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done
    kill -KILL -- "-$pid" 2>/dev/null
    printf '%scancelled%s\n' "$e_red" "$e_off" >>"$current"
    printf 'cancelled\n' >"$status_file"
    rm -f "$job_pid_file" "$question_file" "$answer_file"
}

# The keys stay on the popup's last line, under the log rather than in it:
# the lines above scroll inside a scroll region that leaves that one line out.
# Drawn again when the keys or the popup's height change, and only then.
footer_drawn=''
footer() {
    local rows
    rows=$(tput lines 2>/dev/null) || return 0
    [ "$rows" -gt 2 ] || return 0
    [ "$footer_drawn" != "$rows:$1" ] || return 0
    footer_drawn=$rows:$1
    # Save the cursor, fence the log in above the last line, write the keys
    # there, and put the cursor back. Setting the region homes the cursor,
    # which is why it is saved first.
    printf '\e7\e[1;%dr\e8\e7\e[%d;1H\e[2K%s%s%s\e8' \
        $((rows - 1)) "$rows" "$e_dim" "$1" "$e_off"
}

# Puts the popup's terminal back the way the viewer found it.
footer_off() { printf '\e7\e[r\e8'; }

keys_running='esc: background   ctrl-c: cancel   p: copy log   P: copy log path'
keys_question='y/n: answer   esc: background   ctrl-c: cancel   p: copy log   P: copy log path'
keys_done='p: copy log   P: copy log path   any other key: close'

# A copy's outcome, said in the log area.
copied() { "$1" && printf '%s(%s)%s\n' "$e_dim" "$2" "$e_off" || printf '%s(copying failed)%s\n' "$e_red" "$e_off"; }

view() {
    local offset=0 size key result keys
    printf '%s\n' "$$" >"$viewer_pid_file"
    trap 'cancel_job' INT
    trap 'footer_off; rm -f "$viewer_pid_file"' EXIT
    # Starting on a clean screen, so the region starts with the log.
    printf '\e[2J\e[H'
    while :; do
        size=$(stat -L -c %s "$current" 2>/dev/null || echo 0)
        if [ "$size" -gt "$offset" ]; then
            tail -c +$((offset + 1)) "$current" | head -c $((size - offset))
            offset=$size
        fi
        keys=$keys_running
        [ -s "$question_file" ] && keys=$keys_question
        footer "$keys"
        job_running >/dev/null || break
        key=''
        read -rsn1 -t 0.3 key || continue
        case $key in
            $'\e') exit 0 ;;
            y | n) [ -s "$question_file" ] && printf '%s\n' "$key" >"$answer_file" ;;
            p) copied copy_log 'log copied' ;;
            P) copied copy_log_path 'log path copied' ;;
        esac
    done
    # Whatever it wrote last.
    size=$(stat -L -c %s "$current" 2>/dev/null || echo 0)
    [ "$size" -gt "$offset" ] && tail -c +$((offset + 1)) "$current"
    result=$(cat "$status_file" 2>/dev/null || echo unknown)
    if [ "$result" = ok ]; then
        footer 'done, closing'
        sleep 2
        return
    fi
    printf '\n%s%s.%s the log is %s\n' "$e_red" "$result" "$e_off" "$(readlink -f "$current")"
    footer "$keys_done"
    while read -rsn1 key; do
        case $key in
            p) copied copy_log 'log copied' ;;
            P) copied copy_log_path 'log path copied' ;;
            *) return ;;
        esac
        footer "$keys_done"
    done
}

# --- main ------------------------------------------------------------------

if [ "${1:-}" = --job ]; then
    shift
    run_job "$@"
    exit
fi

# A job still running: back to it, instead of a second one.
if job_running >/dev/null; then
    view
    exit 0
fi

command -v fzf >/dev/null || { fail 'fzf is not installed'; read -rsn1; exit 1; }

note 'looking for devcontainers...'
lines=$(picker_lines)
if [ -z "$lines" ]; then
    warn 'no saved machine points at a port on this machine'
    read -rsn1 -p 'press any key to close'
    exit 0
fi

# The keys go on the last line, as they do while the job runs. fzf clears
# everything below where it starts, so a line drawn before it would be wiped:
# instead they are the label of a bottom border, which fzf draws itself and
# keeps through redraws and resizes. --height=100% and --no-preview override
# FZF_DEFAULT_OPTS, which gives every fzf 40% of the screen and a file
# preview that means nothing for this list.
keys_pick=' enter: start   ctrl-r: restart   ctrl-alt-r: rebuild   (both end its agents)   tab: mark several   esc: close '
out=$(printf '%s\n' "$lines" | fzf --ansi --multi --reverse --no-sort \
    --height=100% --no-preview \
    --border=bottom --border-label="$keys_pick" --border-label-pos=1:bottom \
    --color=label:dim \
    --delimiter $'\t' --with-nth 4 \
    --expect ctrl-r,ctrl-alt-r) || exit 0

key=$(head -n 1 <<<"$out")
case $key in
    ctrl-r) mode=restart ;;
    ctrl-alt-r) mode=rebuild ;;
    *) mode=start ;;
esac

mapfile -t picked < <(tail -n +2 <<<"$out" | cut -f 1-3)
start_job "$mode" "${picked[@]}"
view
