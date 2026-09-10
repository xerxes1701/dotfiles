#!/bin/sh
# Pick a running container with fzf and open a shell in it.
#
# The obvious spelling of this is a pipeline into xargs:
#
#   docker ps -q | xargs docker exec -it ... fish
#
# which cannot work. xargs builds its command from stdin, so the child's stdin
# is the pipe rather than the terminal, `-it` finds no tty and the shell exits
# at once. GNU xargs has --open-tty for exactly this, but by then the command
# substitution below is both shorter and portable.
#
# POSIX sh rather than a per-shell function because the same picker has to be
# reachable from fish, nushell and zsh (see shell-parity.sh) -- three
# dialects, one script, aliased to `dsh` in each.
#
# The script is its own fzf preview: fzf runs `$0 --preview <id>` for whichever
# row the cursor is on, which keeps the renderer next to the picker that uses
# it instead of in a second file.

set -u

self=$(readlink -f -- "$0" 2>/dev/null) || self=$0

# Defaults aimed at the firstx-master devcontainer, which is what this exists
# for; every one of them is checked against the container that gets picked and
# falls back when it does not fit, so the script still works anywhere else.
user=${DOCKER_SHELL_USER-vscode}
dir=${DOCKER_SHELL_DIR-/workspaces/firstx-master}

US=$(printf '\037')     # unit separator: between the fields of a record
RS=$(printf '\036')     # record separator: between records, so that a value
                        # holding newlines (a devcontainer's entrypoint Cmd
                        # does) cannot be mistaken for the next record

# Colors only for a terminal, and never against NO_COLOR or TERM=dumb -- the
# same rule as .local/lib/dotfiles/stow-lib.sh. fzf renders the preview into
# a pty, so `[ -t 1 ]` is true there and the preview keeps its color.
if [ -z "${NO_COLOR:-}" ] && [ "${TERM:-dumb}" != dumb ] && { [ -t 1 ] || [ -t 2 ]; }; then
    c_key=$(printf '\033[1;38;5;110m'); c_hdr=$(printf '\033[1;38;5;214m')
    c_dim=$(printf '\033[2m');          c_off=$(printf '\033[0m')
else
    c_key= c_hdr= c_dim= c_off=
fi

die() { printf 'docker-shell: %s\n' "$1" >&2; exit 1; }

usage() {
    cat <<EOF
usage: $(basename -- "$0") [options] [command...]

Picks one of the running containers with fzf and execs a shell in it.

  -u, --user USER   user to exec as. default: $user (\$DOCKER_SHELL_USER)
                    falls back to the image's own user if absent.
  -w, --workdir DIR working directory. default: $dir (\$DOCKER_SHELL_DIR)
                    falls back to the container's WorkingDir if absent.
  -c, --container S preselect: fzf's initial query. With --exact, and when it
                    leaves exactly one container, that one is used unattended.
  -x, --exact       do not prompt when the query matches a single container.
  -h, --help        this help.

Without a command, tries fish, then bash, then sh -- whichever the container
actually has.

  dsh                     pick, then fish in /workspaces/firstx-master
  dsh -c firstx -x        skip the picker when only one container matches
  dsh -u root bash        same picker, different user and shell
  dsh -w / -- ls -la      a one-shot command instead of a shell

In fzf: enter opens the shell, ctrl-r reloads the list, ctrl-l follows the
logs, ctrl-y copies the container id.
EOF
}

# --- preview ---------------------------------------------------------------
# Invoked by fzf, once per highlighted row, as `$0 --preview <id>`.

preview() {
    pv_id=$1
    pv_cols=${FZF_PREVIEW_COLUMNS:-${COLUMNS:-80}}

    # One inspect call for everything. The template is double-quoted so the
    # separators can be interpolated, which means Go's own $p/$v have to be
    # escaped from the shell -- they are the range variables, not shell ones.
    docker inspect "$pv_id" --format \
"H${US}name${US}{{ .Name }}${RS}\
H${US}image${US}{{ .Config.Image }}${RS}\
H${US}state${US}{{ .State.Status }}{{ if .State.Health }} ({{ .State.Health.Status }}){{ end }}${RS}\
H${US}up${US}{{ .State.StartedAt }}${RS}\
H${US}user${US}{{ if .Config.User }}{{ .Config.User }}{{ else }}root{{ end }}${RS}\
H${US}workdir${US}{{ if .Config.WorkingDir }}{{ .Config.WorkingDir }}{{ else }}/{{ end }}${RS}\
H${US}cmd${US}{{ if .Config.Cmd }}{{ join .Config.Cmd \" \" }}{{ end }}${RS}\
{{ range \$p, \$v := .NetworkSettings.Ports }}\
P${US}{{ \$p }}{{ if \$v }} → localhost:{{ (index \$v 0).HostPort }}{{ end }}${RS}\
{{ end }}\
{{ range .Mounts }}M${US}{{ .Destination }}${US}{{ .Source }}${RS}{{ end }}" 2>/dev/null \
    | LC_ALL=C awk -v RS="$RS" -v FS="$US" -v w="$pv_cols" \
          -v key="$c_key" -v hdr="$c_hdr" -v dim="$c_dim" -v off="$c_off" '
      # A path says most about itself at its tail, an image name or a command
      # line at its head -- so the two are truncated from opposite ends.
      function head(s, n) { return length(s) <= n ? s : substr(s, 1, n - 1) "…" }
      function tail(s, n) { return length(s) <= n ? s : "…" substr(s, length(s) - n + 2) }
      { gsub(/[\n\t]+/, " ") }                      # a Cmd may span lines
      $1 == "H" && $3 != "" {
          v = $3
          if ($2 == "name") sub(/^\//, "", v)       # docker prefixes .Name
          if ($2 == "up") { sub(/\.[0-9]+/, "", v); sub(/T/, "  ", v)
                            sub(/Z$/, " UTC", v) }
          printf "%s%-8s%s %s\n", key, $2, off, head(v, w - 11)
      }
      $1 == "P" { p[++np] = $2 }
      # Insertion-sorted on the destination: POSIX awk has no asort, and the
      # order docker reports mounts in is not one anybody can scan.
      $1 == "M" {
          for (i = nm; i > 0 && md[i] > $2; i--) { md[i+1] = md[i]; ms[i+1] = ms[i] }
          md[i+1] = $2; ms[i+1] = $3; nm++
          if (length($2) > mw) mw = length($2)
      }
      END {
          if (np) { printf "\n%sports%s\n", hdr, off
                    for (i = 1; i <= np; i++) printf "  %s\n", head(p[i], w - 2) }
          if (nm) { printf "\n%smounts%s\n", hdr, off
                    # Neither column gets more than half the pane, so one very
                    # long destination cannot squeeze every source off-screen.
                    cap = int((w - 7) / 2); dw = (mw < cap ? mw : cap)
                    for (i = 1; i <= nm; i++)
                        printf "  %-*s %s←%s %s\n", dw, tail(md[i], dw),
                               dim, off, tail(ms[i], w - 7 - dw) }
      }'

    printf '\n%slogs · last 12%s\n' "$c_hdr" "$c_off"
    docker logs --tail 12 "$pv_id" 2>&1 \
        | cut -c "1-$((pv_cols - 2))" \
        | sed "s/^/  ${c_dim}/;s/\$/${c_off}/"
}

if [ "${1-}" = --preview ]; then
    [ $# -eq 2 ] || die 'usage: --preview <container-id>'
    preview "$2"
    exit 0
fi

# --- options ---------------------------------------------------------------

query= exact=
while [ $# -gt 0 ]; do
    case $1 in
        -u|--user)      [ $# -ge 2 ] || die "$1 needs a user";      user=$2; shift 2 ;;
        -w|--workdir)   [ $# -ge 2 ] || die "$1 needs a directory"; dir=$2;  shift 2 ;;
        -c|--container) [ $# -ge 2 ] || die "$1 needs a filter";    query=$2; shift 2 ;;
        -x|--exact)     exact=1; shift ;;
        -h|--help)      usage; exit 0 ;;
        --)             shift; break ;;
        -*)             die "unknown option: $1  (--help)" ;;
        *)              break ;;
    esac
done

command -v docker >/dev/null 2>&1 || die 'docker is not on $PATH'
command -v fzf    >/dev/null 2>&1 || die 'fzf is not on $PATH'

# --- the list --------------------------------------------------------------
# Tab-separated out of docker, because a container name may hold spaces and
# tabs are the one separator it cannot; `column -t` then pads it into columns,
# after which the id is simply the first space-delimited word of the row.

fmt='{{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}'
# column's -s is a set of literal characters, not a string with escapes: given
# '\t' it splits on every backslash and every letter t, which quietly shreds
# the names it is meant to be aligning. So it gets a real tab, spliced in here
# -- POSIX sh has no $'\t' to write one with.
TAB=$(printf '\t')
# A devcontainer's image name is a 90-character hash that would push Status off
# the pane; the head of it is the part that identifies the project.
list="docker ps --format '$fmt' \
  | awk -F'\t' '{ i = \$3; if (length(i) > 38) i = substr(i, 1, 37) \"…\"
                  print \$1 \"\t\" \$2 \"\t\" i \"\t\" \$4 }' \
  | column -t -s '$TAB'"

rows=$(eval "$list") || die 'docker ps failed'
[ -n "$rows" ] || die 'no running containers'

pick=
if [ -n "$query" ]; then
    # fzf's own matcher, so -c filters exactly the way typing the query would.
    hits=$(printf '%s\n' "$rows" | fzf --filter="$query" 2>/dev/null)
    [ -n "$hits" ] || die "no running container matches: $query"
    if [ -n "$exact" ] && [ "$(printf '%s\n' "$hits" | wc -l)" -eq 1 ]; then
        pick=$hits
    fi
fi

if [ -z "$pick" ]; then
    # fish enables the kitty keyboard protocol and fzf does not implement it
    # (junegunn/fzf#3208), so key-release events would arrive as literal text
    # in fzf's prompt. fish/.config/fish/functions/fzf.fish zeroes the flags
    # for a direct call; this script is reached from three shells and is not
    # that function, so it has to do the same for itself.
    [ -t 2 ] && printf '\033[=0;1u' >/dev/tty 2>/dev/null

    pick=$(printf '%s\n' "$rows" | fzf \
        --ansi --height=90% --reverse --border=rounded \
        --query="$query" \
        --header='enter shell   ^R reload   ^L logs   ^Y copy id' \
        --preview="'$self' --preview {1}" \
        --preview-window='right,60%,border-left,wrap' \
        --bind="ctrl-r:reload($list)" \
        --bind='ctrl-l:execute(docker logs -f --tail 200 {1})' \
        --bind="ctrl-y:execute-silent(printf %s {1} | $(
            if   command -v wl-copy >/dev/null 2>&1; then echo wl-copy
            elif command -v clip.exe >/dev/null 2>&1; then echo clip.exe
            elif command -v xclip   >/dev/null 2>&1; then echo 'xclip -selection clipboard'
            else echo 'cat >/dev/null'; fi))")
    # 130 is fzf's exit for esc/ctrl-c: a deliberate no, not a failure.
    st=$?
    [ $st -eq 0 ] || { [ $st -eq 130 ] && exit 0; die "fzf exited $st"; }
fi

id=${pick%% *}
[ -n "$id" ] || die 'no container selected'

# --- exec ------------------------------------------------------------------
# Every default is checked against the container that was actually picked,
# because the ones above describe one devcontainer and this picker lists all.

if ! docker exec -u "$user" "$id" true >/dev/null 2>&1; then
    printf '%sno user %s in this container, using its own%s\n' "$c_dim" "$user" "$c_off" >&2
    user=
fi

if ! docker exec ${user:+-u "$user"} "$id" test -d "$dir" >/dev/null 2>&1; then
    fallback=$(docker inspect "$id" --format '{{ .Config.WorkingDir }}' 2>/dev/null)
    [ -n "$fallback" ] || fallback=/
    printf '%sno %s in this container, using %s%s\n' "$c_dim" "$dir" "$fallback" "$c_off" >&2
    dir=$fallback
fi

if [ $# -eq 0 ]; then
    for sh in fish bash sh; do
        if docker exec "$id" command -v "$sh" >/dev/null 2>&1; then set -- "$sh"; break; fi
    done
    [ $# -gt 0 ] || die 'container has no fish, bash or sh'
fi

# exec, so the shell replaces this script instead of leaving it waiting: one
# less process between the terminal and the container, and $? comes straight
# from the container's shell.
exec docker exec -it ${user:+-u "$user"} -w "$dir" "$id" "$@"
