#!/usr/bin/env bash
# Install the tools this repository has a package for, picked from a list.
#
# Deploying a package puts its config in place, not the tool that reads it.
# tools.conf says, per tool, which package each manager calls it and whether
# it belongs on linux, on windows or on both; this script finds the manager of
# the machine it runs on, lists the tools that belong here, and installs the
# ones picked:
#
#   cachyos/arch  pacman, and paru for the aur: entries
#   ubuntu/debian apt
#   windows       winget, from git bash
#
# The pick is an fzf multi-select when fzf is there and a numbered menu when it
# is not -- a fresh machine is exactly where this runs, and fzf is one of the
# things it has yet to install. Both offer "all", which means every tool for
# this platform that has a package; a tool without one is listed as one to
# install by hand.
#
# Installing a package is not always the whole of it: rustup installs no
# toolchain, and ubuntu ships bat as batcat. setup.d/<label>.sh, next to
# tools.conf, does what a tool needs after its packages, and runs for every
# tool picked, installed now or before. A hook is sourced in a subshell with
# run, as_root, warn, manager and platform in scope, and defines two functions:
#
#   setup_needed  succeeds when the step is still to do. It asks the machine,
#                 not the manager: bat.sh links only where bat is missing and
#                 batcat is there, so it does nothing on arch or windows, and
#                 nothing the second time.
#   setup_apply   does the step, every command through run, so -n prints it.

set -uo pipefail

self=$(basename -- "$0")

# readlink -f, so this still finds the repository when the script is reached
# through the symlink that stowing `scripts` puts in ~/.local/bin. This file
# lives in scripts/.local/bin, three levels below the repository.
root=$(cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")/../../.." && pwd) \
    || exit 1
conf=$root/scripts/.local/lib/dotfiles/tools.conf
setup_dir=$root/scripts/.local/lib/dotfiles/setup.d

# Same rule as the other scripts here: colors for a terminal only, and never
# against NO_COLOR (https://no-color.org) or TERM=dumb.
if [ -z "${NO_COLOR:-}" ] && [ "${TERM:-dumb}" != dumb ] && { [ -t 1 ] || [ -t 2 ]; }; then
    c_bold=$(printf '\033[1m');         c_dim=$(printf '\033[2m')
    c_ok=$(printf '\033[1;38;5;108m');  c_bad=$(printf '\033[1;38;5;174m')
    c_warn=$(printf '\033[33m');        c_off=$(printf '\033[0m')
else
    c_bold= c_dim= c_ok= c_bad= c_warn= c_off=
fi

die() {
    printf '%s%s: error:%s %s\n' "$c_bad" "$self" "$c_off" "$1" >&2
    shift
    for hint in "$@"; do printf '%s  %s%s\n' "$c_dim" "$hint" "$c_off" >&2; done
    exit 1
}
warn() { printf '%s%s: warning:%s %s\n' "$c_warn" "$self" "$c_off" "$1" >&2; }

run() {
    printf '%s$ %s%s\n' "$c_dim" "$*" "$c_off"
    [ "$dry" = 1 ] || "$@"
}

# A container is usually root and often has no sudo.
as_root() { if [ "$(id -u)" = 0 ]; then run "$@"; else run sudo "$@"; fi; }

usage() {
    cat <<EOF
usage: $self [options] [tool...]

Install the tools listed in $conf
that belong on this platform, picked from a list.

  -a, --all            every tool for this platform, without asking which.
  -l, --list           list the tools for this platform, and exit.
  -m, --manager NAME   pacman, apt or winget instead of the detected one.
  -n, --dry-run        print the commands, run nothing.
  -s, --setup          only the setup steps of the tools here, install nothing.
  -y, --yes            do not ask before installing.
  -h, --help           this.

Named tools are installed without the list, e.g. $self nvim tmux.
EOF
    exit 0
}

all=0 list=0 dry=0 yes=0 setup_only=0 manager=''
while [ $# -gt 0 ]; do
    case $1 in
        -a | --all)     all=1; shift ;;
        -l | --list)    list=1; shift ;;
        -m | --manager) [ -n "${2:-}" ] || die "$1 needs a value" 'pacman, apt or winget'
                        manager=$2; shift 2 ;;
        --manager=*)    manager=${1#*=}; shift ;;
        -n | --dry-run) dry=1; shift ;;
        -s | --setup)   setup_only=1; shift ;;
        -y | --yes)     yes=1; shift ;;
        -h | --help)    usage ;;
        --)             shift; break ;;
        -?*)            die "unknown option $1" "$self --help" ;;
        *)              break ;;
    esac
done
wanted=("$@")

[ -r "$conf" ] || die "cannot read $conf"

# --- platform --------------------------------------------------------------

# Git Bash is msys; WSL is a linux host with the distro's own manager.
detect_manager() {
    if [ -n "${MSYSTEM:-}" ]; then echo winget; return; fi
    case ${OSTYPE:-} in msys | cygwin) echo winget; return ;; esac
    [ -r /etc/os-release ] || return 1
    local id
    for id in $(. /etc/os-release && echo "${ID:-} ${ID_LIKE:-}"); do
        case $id in
            arch | cachyos)  echo pacman; return ;;
            debian | ubuntu) echo apt; return ;;
        esac
    done
    return 1
}

if [ -z "$manager" ]; then
    manager=$(detect_manager) \
        || die 'cannot tell which package manager this machine uses' \
               'name it with --manager pacman, --manager apt or --manager winget'
fi
case $manager in
    pacman) platform=linux col=3 ;;
    apt)    platform=linux col=4 ;;
    winget) platform=windows col=5 ;;
    *)      die "unknown manager $manager" 'pacman, apt or winget' ;;
esac
[ "$list" = 1 ] || [ "$dry" = 1 ] || [ "$setup_only" = 1 ] || command -v "$manager" >/dev/null 2>&1 \
    || die "$manager is not on PATH"

# --- tools.conf ------------------------------------------------------------

# t_* are parallel arrays of the tools that have a package here; manual holds
# the labels of those that belong on this platform but have none, and labels
# every tool for this platform, in the file's order, for the setup steps.
t_label=() t_pkgs=() t_desc=() manual=() labels=()
while read -r label os c3 c4 c5 desc; do
    case $label in '' | '#'*) continue ;; esac
    case ,$os, in *,$platform,*) ;; *) continue ;; esac
    labels+=("$label")
    case $col in 3) pkgs=$c3 ;; 4) pkgs=$c4 ;; 5) pkgs=$c5 ;; esac
    if [ "$pkgs" = - ]; then
        manual+=("$label")
    else
        t_label+=("$label") t_pkgs+=("$pkgs") t_desc+=("$desc")
    fi
done <"$conf"

[ ${#t_label[@]} -gt 0 ] || die "tools.conf lists nothing for $manager"

# --- setup steps -----------------------------------------------------------

# For the hooks that only give a binary the name the configs call it by.
# Needed when the name is missing, the other one is there, and no link was
# made before -- one in a ~/.local/bin that is not on PATH yet included.
link_needed() {
    ! command -v "$1" >/dev/null 2>&1 && command -v "$2" >/dev/null 2>&1 \
        && [ ! -e "$HOME/.local/bin/$1" ]
}
link_apply() {
    run mkdir -p "$HOME/.local/bin" && run ln -s "$(command -v "$2")" "$HOME/.local/bin/$1"
}

# Runs the hooks of the labels given, in tools.conf's order, and records the
# ones that failed in setup_failed.
setup_failed=()
run_setup() {
    local label hook
    for label in "${labels[@]}"; do
        case " $* " in *" $label "*) ;; *) continue ;; esac
        hook=$setup_dir/$label.sh
        [ -r "$hook" ] || continue
        ( . "$hook" && setup_needed ) || continue
        printf '%ssetting up %s%s\n' "$c_bold" "$label" "$c_off"
        ( . "$hook" && setup_apply ) || setup_failed+=("$label")
    done
}

if [ "$setup_only" = 1 ]; then
    for label in "${wanted[@]}"; do
        case " ${labels[*]} " in *" $label "*) ;; *) die "no $label for $platform in tools.conf" ;; esac
    done
    if [ ${#wanted[@]} -gt 0 ]; then run_setup "${wanted[@]}"; else run_setup "${labels[@]}"; fi
    [ ${#setup_failed[@]} -eq 0 ] || die "setup failed: ${setup_failed[*]}"
    printf '%sdone.%s\n' "$c_ok" "$c_off"
    exit 0
fi

# --- installed or not ------------------------------------------------------

# winget is slow to ask, so it is asked once for everything it has installed.
# Its table pads and may truncate long names, but not the ids looked up here.
# An id counts only as a whole column, compared without case the way winget
# does: as a substring, Git.Git would be found in Git.GitLFS.
winget_list=''
if [ "$manager" = winget ] && command -v winget >/dev/null 2>&1; then
    winget_list=$(winget list --accept-source-agreements --disable-interactivity 2>/dev/null)
fi

pkg_installed() {
    case $manager in
        pacman) pacman -Q -- "$1" >/dev/null 2>&1 ;;
        apt)    dpkg-query -W -f='${Status}' -- "$1" 2>/dev/null | grep -q 'ok installed' ;;
        winget) awk -v id="$1" 'BEGIN { id = tolower(id) }
                    { for (i = 1; i <= NF; i++) if (tolower($i) == id) { found = 1; exit } }
                    END { exit !found }' <<<"$winget_list" ;;
    esac
}

# A tool counts as installed when every one of its packages is.
t_state=()
for i in "${!t_label[@]}"; do
    state=installed
    IFS=, read -ra ps <<<"${t_pkgs[i]}"
    for p in "${ps[@]}"; do pkg_installed "${p#aur:}" || { state=''; break; }; done
    t_state+=("$state")
done

row() {
    printf '%-12s %s%-9s%s %s\n' "${t_label[$1]}" "$c_ok" "${t_state[$1]}" "$c_off" "${t_desc[$1]}"
}

print_manual() {
    [ ${#manual[@]} -gt 0 ] || return 0
    printf '%sno %s package, install by hand (see the README): %s%s\n' \
        "$c_dim" "$manager" "${manual[*]}" "$c_off"
}

if [ "$list" = 1 ]; then
    printf '%stools for %s, through %s:%s\n' "$c_bold" "$platform" "$manager" "$c_off"
    for i in "${!t_label[@]}"; do printf '  '; row "$i"; done
    print_manual
    exit 0
fi

# --- the pick --------------------------------------------------------------

picked=()

index_of() {
    local i
    for i in "${!t_label[@]}"; do [ "${t_label[i]}" = "$1" ] && { echo "$i"; return 0; }; done
    return 1
}

pick_fzf() {
    local lines i out label
    lines=$(printf 'all          every tool for %s\n' "$platform"
            for i in "${!t_label[@]}"; do row "$i"; done)
    out=$(fzf --multi --ansi --reverse --height=~60% \
              --prompt="install> " \
              --header="tab picks, enter installs, esc cancels -- through $manager" \
              <<<"$lines") || return 0
    while read -r label _; do
        [ -n "$label" ] || continue
        if [ "$label" = all ]; then picked=("${!t_label[@]}"); return 0; fi
        picked+=("$(index_of "$label")")
    done <<<"$out"
}

pick_menu() {
    local i answer tok
    printf '%stools for %s, through %s:%s\n' "$c_bold" "$platform" "$manager" "$c_off"
    for i in "${!t_label[@]}"; do printf '  %2d) ' $((i + 1)); row "$i"; done
    printf '   a) all\n'
    print_manual
    read -rp 'install which? (numbers, a for all, enter for none) ' answer || return 0
    for tok in ${answer//,/ }; do
        case $tok in
            a | all) picked=("${!t_label[@]}"); return 0 ;;
            *[!0-9]* | '') die "not a number: $tok" ;;
        esac
        [ "$tok" -ge 1 ] && [ "$tok" -le ${#t_label[@]} ] || die "no tool $tok in the list"
        picked+=($((tok - 1)))
    done
}

if [ ${#wanted[@]} -gt 0 ]; then
    for label in "${wanted[@]}"; do
        i=$(index_of "$label") \
            || die "no $manager package for $label in tools.conf" "$self --list shows the ones there are"
        picked+=("$i")
    done
elif [ "$all" = 1 ]; then
    picked=("${!t_label[@]}")
else
    if command -v fzf >/dev/null 2>&1 && [ -t 0 ] && [ -t 1 ]; then
        print_manual; pick_fzf
    else
        pick_menu
    fi
fi

# A number typed twice, or a tool named twice, is installed once. Guarded,
# since printf with nothing to print still prints a newline, and an empty
# entry would index the first tool.
[ ${#picked[@]} -eq 0 ] || mapfile -t picked < <(printf '%s\n' "${picked[@]}" | sort -nu)
[ ${#picked[@]} -gt 0 ] || { echo 'nothing picked.'; exit 0; }

# --- install ---------------------------------------------------------------

# A tool that is there already is left out: pacman --needed and apt would skip
# it anyway, but winget would reinstall it or fail.
repo=() aur=() skipped=()
for i in "${picked[@]}"; do
    if [ -n "${t_state[i]}" ]; then
        skipped+=("${t_label[i]}"); continue
    fi
    IFS=, read -ra ps <<<"${t_pkgs[i]}"
    for p in "${ps[@]}"; do
        case $p in aur:*) aur+=("${p#aur:}") ;; *) repo+=("$p") ;; esac
    done
done
[ ${#skipped[@]} -eq 0 ] || printf '%salready installed: %s%s\n' "$c_dim" "${skipped[*]}" "$c_off"

failed=()
if [ $(( ${#repo[@]} + ${#aur[@]} )) -eq 0 ]; then
    echo 'nothing to install.'
else
    if [ "$manager" = pacman ] && [ ${#aur[@]} -gt 0 ] && [ "$dry" = 0 ] \
        && ! command -v paru >/dev/null 2>&1; then
        die "paru is not on PATH, and ${aur[*]} come from the aur" \
            'install paru first: sudo pacman -S paru'
    fi

    printf '%sto install:%s %s\n' "$c_bold" "$c_off" "${repo[*]}${aur[*]:+ ${aur[*]}}"
    if [ "$dry" = 0 ] && [ "$yes" = 0 ]; then
        read -rp 'go ahead? [y/N] ' answer || exit 1
        case $answer in y | Y | yes) ;; *) echo 'nothing installed.'; exit 0 ;; esac
    fi

    case $manager in
        pacman)
            if [ ${#repo[@]} -gt 0 ]; then
                as_root pacman -S --needed -- "${repo[@]}" || failed+=("${repo[@]}")
            fi
            if [ ${#aur[@]} -gt 0 ]; then
                run paru -S --needed -- "${aur[@]}" || failed+=("${aur[@]}")
            fi
            ;;
        apt)
            as_root apt-get update || die 'apt-get update failed'
            # Asked after the update: a package the release does not have makes
            # apt refuse the whole install, so it is left out with a warning.
            have=()
            for p in "${repo[@]}"; do
                cand=$(apt-cache policy "$p" 2>/dev/null | awk '/Candidate:/ {print $2}')
                if [ "$dry" = 0 ] && { [ -z "$cand" ] || [ "$cand" = '(none)' ]; }; then
                    warn "this release has no $p package, install it by hand"
                    failed+=("$p")
                else
                    have+=("$p")
                fi
            done
            if [ ${#have[@]} -gt 0 ]; then
                as_root apt-get install -y -- "${have[@]}" || failed+=("${have[@]}")
            fi
            ;;
        winget)
            for id in "${repo[@]}"; do
                run winget install --exact --id "$id" \
                    --accept-package-agreements --accept-source-agreements \
                    || failed+=("$id")
            done
            ;;
    esac
fi

# Every tool picked, the ones there already included: a machine that had
# rustup before this script knew to set it up gets its toolchain now. A hook
# whose tool failed to install finds nothing to do.
picked_labels=()
for i in "${picked[@]}"; do picked_labels+=("${t_label[i]}"); done
run_setup "${picked_labels[@]}"

[ "$dry" = 1 ] && exit 0
[ ${#failed[@]} -eq 0 ] || die "not installed: ${failed[*]}" \
    ${setup_failed[@]:+"setup failed: ${setup_failed[*]}"}
[ ${#setup_failed[@]} -eq 0 ] || die "setup failed: ${setup_failed[*]}"
printf '%sdone.%s\n' "$c_ok" "$c_off"
