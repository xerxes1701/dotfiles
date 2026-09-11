#!/bin/sh
# Rebuild devcontainers -- what VS Code's *Dev Containers: Rebuild Container*
# does, for one project or for all of them, picked with fzf.
#
# It finds every project one level under the roots below that carries a
# devcontainer config, and runs the same `devcontainer up` the VS Code
# extension runs, with the flags that make the result the container VS Code
# then recognizes as *the* one for that folder. Getting that wrong does not
# fail loudly -- it leaves a second container behind and VS Code builds its own
# on the next attach -- so the identity is worked out per project instead of
# assumed:
#
#   * VS Code stamps devcontainer.local_folder with the path *it* opened. On
#     Windows that is `c:\SWProjekte\x` (lower-case drive, backslashes), while
#     the same extension writes devcontainer.config_file and the workspace bind
#     mount as the docker host sees them: `/mnt/c/SWProjekte/x`. All three were
#     read off a container this machine's VS Code built; the CLI on its own
#     writes the WSL form for every one of them.
#   * so a project that already has a container reuses that container's own
#     labels verbatim -- the most faithful thing available -- and only a project
#     without one falls back to the rule above (--label-style).
#   * --mount-workspace-git-root false, because that flag is the CLI's own
#     convenience: it mounts the git root and treats the opened folder as a
#     subpath, which the extension does not do. These worktrees are their own
#     git root, so it changes nothing today and everything the day a subfolder
#     is opened.
#
# Builds run one at a time on purpose. Two concurrent devcontainer builds are
# what took WSL down in .devcontainer/issues/wsl-memory-and-container-sharing.md,
# and a rebuild is the memory-hungry half of that.
#
# POSIX sh and self-previewing for the same reasons docker-shell.sh is: one
# picker reachable from every shell, and a preview fzf can re-run per row. Not
# a dc_ launcher -- those exec a tool *in* a container, this replaces the
# container itself.

set -u

self=$(readlink -f -- "$0" 2>/dev/null) || self=$0

# One level down each of these is a project, and a project with a devcontainer
# config is a candidate. Space-separated, overridable for a machine that keeps
# its checkouts elsewhere.
roots=${DEVCONTAINER_REBUILD_ROOTS-"$HOME/SWProjekte /mnt/c/SWProjekte"}

style=${DEVCONTAINER_REBUILD_STYLE-auto}
nocache=${DEVCONTAINER_REBUILD_NOCACHE-}
logdir=${XDG_STATE_HOME:-$HOME/.local/state}/devcontainer-rebuild

TAB=$(printf '\t')
NL='
'

if [ -z "${NO_COLOR:-}" ] && [ "${TERM:-dumb}" != dumb ] && { [ -t 1 ] || [ -t 2 ]; }; then
    c_key=$(printf '\033[1;38;5;110m'); c_hdr=$(printf '\033[1;38;5;214m')
    c_dim=$(printf '\033[2m');          c_off=$(printf '\033[0m')
    c_ok=$(printf '\033[1;38;5;108m');  c_bad=$(printf '\033[1;38;5;174m')
else
    c_key= c_hdr= c_dim= c_off= c_ok= c_bad=
fi

die() {
    printf 'devcontainer-rebuild: %s\n' "$1" >&2
    shift
    for hint in "$@"; do printf '%s  %s%s\n' "$c_dim" "$hint" "$c_off" >&2; done
    exit 1
}

usage() {
    cat <<EOF
usage: $(basename -- "$0") [options] [project...]

Rebuilds devcontainers the way *Dev Containers: Rebuild Container* does. With
no project named, fzf picks -- tab selects several, ctrl-a takes all.

  -a, --all           every project found, without the picker
      --no-cache      VS Code's "Rebuild Container Without Cache"
  -y, --yes           do not ask before replacing the containers
  -n, --dry-run       print the command per project, run nothing
      --label-style S how to identify a project that has no container yet:
                      auto (default), windows, wsl. A project that *has* one
                      always reuses that container's own labels.
      --roots "A B"   where to look, one level down each. default:
                      $roots
                      (\$DEVCONTAINER_REBUILD_ROOTS)
  -h, --help          this help.

  $(basename -- "$0")                       pick one or several
  $(basename -- "$0") -a -y                 everything, unattended
  $(basename -- "$0") firstx-a firstx-b     by name, no picker
  $(basename -- "$0") firstx-master -n      the exact command, without running it

Each rebuild is \`devcontainer up --remove-existing-container\`, which runs
initializeCommand on this side and onCreate/postCreate/postStart/postAttach in
the container, as VS Code does. Sequentially: two builds at once is what took
WSL down in .devcontainer/issues/wsl-memory-and-container-sharing.md.

Logs land in $logdir.
EOF
}

# --- paths and identity ----------------------------------------------------

# /mnt/c/SWProjekte/x -> c:\SWProjekte\x, which is the spelling VS Code puts in
# the label: a lower-case drive letter (it comes from a file URI, where VS Code
# lower-cases it) and backslashes. Prints nothing for a path that is not on a
# Windows drive, which is how the caller detects that.
win_path() {
    LC_ALL=C printf '%s\n' "$1" | awk '
        /^\/mnt\/[a-zA-Z]\// {
            d = substr($0, 6, 1); rest = substr($0, 8)
            gsub(/\//, "\\", rest)
            printf "%s:\\%s\n", tolower(d), rest }'
}

# One spelling to compare two labels by: case-folded, forward slashes, drive
# letters back to /mnt. The same divide devcontainer-lib.sh's dc_normalize_path
# has to bridge.
norm_path() {
    LC_ALL=C printf '%s\n' "$1" | tr 'A-Z\\' 'a-z/' \
        | sed 's!^\([a-z]\):/!/mnt/\1/!; s!/*$!!'
}

# Containers whose local_folder label means this folder, whichever side wrote
# it: id<TAB>state<TAB>local_folder<TAB>config_file<TAB>name, newest first.
containers_for() {
    docker ps -a --filter label=devcontainer.local_folder \
        --format "{{.ID}}${TAB}{{.State}}${TAB}{{.Label \"devcontainer.local_folder\"}}${TAB}{{.Label \"devcontainer.config_file\"}}${TAB}{{.Names}}" \
        2>/dev/null \
    | while IFS="$TAB" read -r cf_id cf_state cf_folder cf_config cf_name; do
          [ "$(norm_path "$cf_folder")" = "$(norm_path "$1")" ] || continue
          printf '%s\t%s\t%s\t%s\t%s\n' \
              "$cf_id" "$cf_state" "$cf_folder" "$cf_config" "$cf_name"
      done
}

# The --id-label pair for a project, as two lines: the existing container's own
# labels when there is one, the style rule when there is not. Two lines rather
# than one string because a label holds a backslash, which no separator here
# should have to survive.
id_labels_for() {
    il_dir=$1 il_config=$2

    # What the style rule would write, which is also the tie-breaker below.
    case $style in
        wsl) il_want=$il_dir ;;
        *)   il_want=$(win_path "$il_dir") ;;
    esac
    # A path that is not on a Windows drive has only the one spelling.
    [ -n "$il_want" ] || il_want=$il_dir

    # Two containers for one folder happen -- one built by VS Code, one by the
    # CLI, under two spellings of the same path. Rebuilding the wrong one is
    # how a duplicate survives, so the preferred spelling wins over recency,
    # and recency only decides when neither matches it.
    il_all=$(containers_for "$il_dir")
    # Through the environment, not through -v: awk expands escape sequences in
    # a -v assignment, and this value is a Windows path -- `\S` would warn and
    # become `S`, `\f` a form feed, and the comparison would never match.
    il_existing=$(printf '%s\n' "$il_all" \
        | WANT="$il_want" LC_ALL=C awk -F"$TAB" '$3 == ENVIRON["WANT"] { print; exit }')
    [ -n "$il_existing" ] || il_existing=$(printf '%s\n' "$il_all" | head -1)

    il_folder=$(printf '%s\n' "$il_existing" | cut -f3)
    il_cfglbl=$(printf '%s\n' "$il_existing" | cut -f4)

    [ -n "$il_folder" ] || il_folder=$il_want
    # Never the Windows spelling: the extension writes this one as the docker
    # host sees it, even when the folder label is a Windows path.
    [ -n "$il_cfglbl" ] || il_cfglbl=$il_config

    printf '%s\n%s\n' "$il_folder" "$il_cfglbl"
}

# The command, one argument per line, so the preview can show exactly what runs
# and the caller can rebuild it into "$@" without quoting games.
build_argv() {
    ba_dir=$1 ba_config=$2
    ba_labels=$(id_labels_for "$ba_dir" "$ba_config")
    ba_folder=${ba_labels%%"$NL"*}
    ba_cfglbl=${ba_labels#*"$NL"}
    ba_cfglbl=${ba_cfglbl%"$NL"}

    set -- devcontainer up --workspace-folder "$ba_dir"
    # Only when it is not the path the CLI looks up by itself, so the common
    # case reads like the documented command.
    [ "$ba_config" = "$ba_dir/.devcontainer/devcontainer.json" ] \
        || set -- "$@" --config "$ba_config"
    set -- "$@" --id-label "devcontainer.local_folder=$ba_folder"
    set -- "$@" --id-label "devcontainer.config_file=$ba_cfglbl"
    set -- "$@" --remove-existing-container --mount-workspace-git-root false
    [ -z "$nocache" ] || set -- "$@" --build-no-cache
    printf '%s\n' "$@"
}

# --- discovery -------------------------------------------------------------
# Rows are tab-separated: a padded display column first, then the data the rest
# of the script works with. fzf shows field 1 and hands the whole line back,
# which keeps the alignment here and the parsing exact -- a path with a space
# in it would defeat `column -t` plus "the first word is the id".

discover() {
    for root in $roots; do
        [ -d "$root" ] || continue
        for dir in "$root"/*/; do
            dir=${dir%/}
            [ -d "$dir" ] || continue
            for cfg in "$dir/.devcontainer/devcontainer.json" "$dir/.devcontainer.json"; do
                [ -f "$cfg" ] && printf '%s\t%s\n' "$dir" "$cfg"
            done
            # A folder may hold several configs, one per subdirectory; VS Code
            # asks which one, so each is a row of its own here.
            for cfg in "$dir"/.devcontainer/*/devcontainer.json; do
                [ -f "$cfg" ] && printf '%s\t%s\n' "$dir" "$cfg"
            done
        done
    done
}

rows() {
    discover | while IFS="$TAB" read -r dir cfg; do
        name=$(basename -- "$dir")
        case $cfg in
            "$dir/.devcontainer/devcontainer.json"|"$dir/.devcontainer.json") ;;
            # A second config in one folder is only distinguishable by the
            # directory holding it, so that becomes part of the name.
            *) name="$name/$(basename -- "$(dirname -- "$cfg")")" ;;
        esac

        found=$(containers_for "$dir")
        if [ -n "$found" ]; then
            state=$(printf '%s\n' "$found" | head -1 | cut -f2)
            extra=$(printf '%s\n' "$found" | grep -c .)
            [ "$extra" -le 1 ] || state="$state +$((extra - 1))"
        else
            state='no container'
        fi

        case $dir in
            /mnt/*) side=windows ;;
            *)      side=wsl ;;
        esac

        printf '%-24s %-14s %-8s %s\t%s\t%s\t%s\n' \
            "$name" "$state" "$side" "$dir" "$dir" "$cfg" "$name"
    done
}

# --- preview ---------------------------------------------------------------
# fzf calls this back as `$0 --preview <folder> <config>`. Local reads only:
# the config file, docker's own list, and the command that would run. Nothing
# builds and nothing starts, so moving the cursor is always cheap.

preview() {
    pv_dir=$1 pv_cfg=$2

    printf '%sfolder%s   %s\n' "$c_key" "$c_off" "$pv_dir"
    printf '%sconfig%s   %s\n' "$c_key" "$c_off" "${pv_cfg#"$pv_dir"/}"

    # The name out of the config without a JSON parser: these files carry
    # comments and trailing commas, so `devcontainer read-configuration` is the
    # only correct reader of them -- and too slow to run for every row. One
    # line is enough to confirm which project this is.
    pv_name=$(sed -n 's/^[[:space:]]*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
        "$pv_cfg" 2>/dev/null | head -1)
    [ -z "$pv_name" ] || printf '%sname%s     %s\n' "$c_key" "$c_off" "$pv_name"

    printf '\n%scontainers for this folder%s\n' "$c_hdr" "$c_off"
    pv_found=$(containers_for "$pv_dir")
    if [ -z "$pv_found" ]; then
        printf '  %snone -- this rebuild creates the first one%s\n' "$c_dim" "$c_off"
    else
        printf '%s\n' "$pv_found" | while IFS="$TAB" read -r p_id p_state p_folder p_cfg p_name; do
            case $p_state in
                running) printf '  %-13s %s%-9s%s %s\n' \
                             "$p_id" "$c_ok" "$p_state" "$c_off" "$p_name" ;;
                *)       printf '  %-13s %s%-9s%s %s\n' \
                             "$p_id" "$c_dim" "$p_state" "$c_off" "$p_name" ;;
            esac
            printf '    %slocal_folder %s%s\n' "$c_dim" "$p_folder" "$c_off"
        done
        # More than one is the failure this script exists to avoid: two
        # containers for one folder, built under two different spellings.
        [ "$(printf '%s\n' "$pv_found" | grep -c .)" -le 1 ] || \
            printf '  %stwo containers for one folder -- the labels below decide%s\n' \
                "$c_bad" "$c_off"
    fi

    printf '\n%swhat would run%s\n' "$c_hdr" "$c_off"
    build_argv "$pv_dir" "$pv_cfg" | LC_ALL=C awk -v dim="$c_dim" -v off="$c_off" '
        # One flag per line with its value, so a label with a backslash in it
        # stays readable and nothing looks like shell quoting that is not.
        NR == 1 { first = $0; next }
        NR == 2 { printf "  %s %s\n", first, $0; next }
        /^--/   { if (pending != "") print pending
                  pending = "    " dim $0 off; next }
        { pending = pending " " $0 }
        END { if (pending != "") print pending }'
}

# The preview callback comes first and always alone: fzf builds that command
# itself, and its two arguments are positional.
if [ "${1-}" = --preview ]; then
    [ $# -eq 3 ] || die 'usage: --preview <folder> <config>'
    preview "$2" "$3"
    exit 0
fi

# --- options ---------------------------------------------------------------

all= yes= dry= listrows=
while [ $# -gt 0 ]; do
    case $1 in
        -a|--all)       all=1; shift ;;
        --no-cache)     nocache=1; shift ;;
        -y|--yes)       yes=1; shift ;;
        -n|--dry-run)   dry=1; shift ;;
        --label-style)  [ $# -ge 2 ] || die "$1 needs auto, windows or wsl"
                        style=$2; shift 2 ;;
        --roots)        [ $# -ge 2 ] || die "$1 needs a list of directories"
                        roots=$2; shift 2 ;;
        # What ctrl-R in the picker re-runs, so a container started or removed
        # in another window shows up without leaving fzf. An option rather than
        # a first-argument mode, so it can be combined with --roots -- which is
        # also how it is testable.
        --list-rows)    listrows=1; shift ;;
        -h|--help)      usage; exit 0 ;;
        --)             shift; break ;;
        -*)             die "unknown option: $1  (--help)" ;;
        *)              break ;;
    esac
done
case $style in auto|windows|wsl) ;; *) die "unknown --label-style: $style" ;; esac

command -v docker       >/dev/null 2>&1 || die 'docker is not on $PATH'
command -v devcontainer >/dev/null 2>&1 || die 'the devcontainer CLI is not on $PATH' \
    'it is what VS Code drives too:  npm i -g @devcontainers/cli'
[ $# -gt 0 ] || [ -n "$all" ] || command -v fzf >/dev/null 2>&1 \
    || die 'fzf is not on $PATH' 'name the projects instead, or pass --all'

if [ -n "$listrows" ]; then
    rows
    exit 0
fi

available=$(rows)
[ -n "$available" ] || die 'no devcontainer config under any root' \
    "looked one level under: $roots" \
    'somewhere else: --roots "DIR DIR"'

# --- selection -------------------------------------------------------------

if [ $# -gt 0 ]; then
    picked=
    for want in "$@"; do
        hit=$(printf '%s\n' "$available" | LC_ALL=C awk -F"$TAB" -v w="$want" \
            '$4 == w { print; exit }')
        [ -n "$hit" ] || die "no project named: $want" \
            'what there is:' "$(printf '%s\n' "$available" | cut -f4 | tr '\n' ' ')"
        picked=${picked:+$picked$NL}$hit
    done
elif [ -n "$all" ]; then
    picked=$available
else
    # The same kitty-keyboard reset docker-shell.sh does: fish enables the
    # protocol, fzf does not implement it, and the key-release events would
    # otherwise arrive as literal text in the prompt.
    [ -t 2 ] && printf '\033[=0;1u' >/dev/tty 2>/dev/null

    picked=$(printf '%s\n' "$available" | DEVCONTAINER_REBUILD_NOCACHE="$nocache" \
        DEVCONTAINER_REBUILD_STYLE="$style" DEVCONTAINER_REBUILD_ROOTS="$roots" fzf \
        --ansi --multi --height=90% --reverse --border=rounded \
        --delimiter="$TAB" --with-nth=1 \
        --header='tab select   ^A all   ^D none   enter rebuild   ^R reload' \
        --preview="'$self' --preview {2} {3}" \
        --preview-window='right,60%,border-left,wrap' \
        --bind='ctrl-a:select-all' \
        --bind='ctrl-d:deselect-all' \
        --bind="ctrl-r:reload('$self' --list-rows)")
    st=$?
    [ $st -eq 0 ] || { [ $st -eq 130 ] && exit 0; die "fzf exited $st"; }
fi
[ -n "$picked" ] || die 'nothing selected'

# --- confirm ---------------------------------------------------------------
# A rebuild deletes the container it replaces, and everything running in it
# goes with it -- agents included. So the running ones are named before the
# question, not after it.

printf '%s%s devcontainer(s) to rebuild%s%s\n' \
    "$c_hdr" "$(printf '%s\n' "$picked" | grep -c .)" \
    "${nocache:+, without cache}" "$c_off"
printf '%s\n' "$picked" | while IFS="$TAB" read -r disp dir cfg name; do
    running=$(containers_for "$dir" | LC_ALL=C awk -F"$TAB" '$2 == "running" { printf "%s ", $1 }')
    if [ -n "$running" ]; then
        printf '  %-24s %sreplaces a running container (%s) -- its processes stop%s\n' \
            "$name" "$c_bad" "${running% }" "$c_off"
    else
        printf '  %-24s %s%s%s\n' "$name" "$c_dim" "$dir" "$c_off"
    fi
done

if [ -z "$yes" ] && [ -z "$dry" ]; then
    printf '%sproceed? [y/N] %s' "$c_hdr" "$c_off"
    # From the terminal, not from stdin: stdin may still be the pipe the rows
    # came down.
    read -r answer </dev/tty || answer=
    case $answer in y|Y|yes|Yes) ;; *) printf 'nothing done\n'; exit 0 ;; esac
fi

# --- rebuild ---------------------------------------------------------------

[ -n "$dry" ] || mkdir -p "$logdir" || die "cannot create $logdir"
stamp=$(date +%Y%m%d-%H%M%S)

# One subshell for the whole loop, so the counters survive it and the script's
# exit status is the pipeline's.
printf '%s\n' "$picked" | {
    failed=0 summary=

    while IFS="$TAB" read -r disp dir cfg name; do
        printf '\n%s=== %s%s  %s%s%s\n' \
            "$c_hdr" "$name" "$c_off" "$c_dim" "$dir" "$c_off"

        if [ -n "$dry" ]; then
            build_argv "$dir" "$cfg" | tr '\n' ' ' | sed 's/  *$//;s/^/  /'
            printf '\n'
            continue
        fi

        # Rebuilt into "$@" one line at a time, so a label containing a
        # backslash reaches the CLI as one argument, unmangled.
        set --
        while IFS= read -r arg; do set -- "$@" "$arg"; done <<EOF
$(build_argv "$dir" "$cfg")
EOF

        log="$logdir/$(printf '%s' "$name" | tr '/' '-')-$stamp.log"
        # tee: the build log is both watchable and kept. VS Code shows it in a
        # terminal, and a failure an hour later still needs it.
        if "$@" 2>&1 | tee "$log"; then
            cid=$(LC_ALL=C sed -n 's/.*"containerId":"\([0-9a-f]\{12\}\).*/\1/p' \
                "$log" | tail -1)
            printf '%s✓ %s%s  %s%s%s\n' "$c_ok" "$name" "$c_off" \
                "$c_dim" "${cid:-rebuilt}" "$c_off"
            summary="${summary}ok${TAB}${name}${TAB}${cid:-rebuilt}${NL}"
        else
            printf '%s✗ %s%s  %s%s%s\n' "$c_bad" "$name" "$c_off" "$c_dim" "$log" "$c_off"
            summary="${summary}failed${TAB}${name}${TAB}${log}${NL}"
            failed=$((failed + 1))
        fi
    done

    [ -n "$summary" ] || exit 0
    printf '\n%ssummary%s\n' "$c_hdr" "$c_off"
    printf '%s' "$summary" | while IFS="$TAB" read -r st name detail; do
        case $st in
            ok) printf '  %s%-6s%s %-24s %s\n' "$c_ok" ok "$c_off" "$name" "$detail" ;;
            *)  printf '  %s%-6s%s %-24s %s\n' "$c_bad" failed "$c_off" "$name" "$detail" ;;
        esac
    done
    [ "$failed" -eq 0 ] || exit 1
}
