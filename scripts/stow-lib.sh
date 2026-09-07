# Shared logic of the stow-deploy*.sh scripts. Sourced, never run.
#
# A launcher names the environment it belongs to and hands over:
#
#   . "$(dirname -- "$(readlink -f -- "$0")")/stow-lib.sh"
#   sd_where=host                     # or devcontainer
#   sd_exclude=(git herdr)            # packages this environment replaces
#   sd_extra=(.herdr-devcontainer)    # hidden packages, which */ never matches
#   sd_unfolded=(fish herdr)          # packages to stow with --no-folding
#   sd_examples=("$self -n")
#   sd_main "$@"
#
# Why a script, when the README's instruction is a single `stow */`: stow folds
# a package into one symlink whenever its target directory does not exist yet,
# so ~/.config/fish becomes a link into this repository -- and then everything
# the tool writes into its own config directory lands in the working tree.
# Which packages must stay unfolded, and which ones a devcontainer replaces, is
# knowledge that belongs in a file rather than in a habit.

# Sourcing is the only supported use: on its own this file knows no environment
# to deploy for.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    printf 'stow-lib.sh is a library. Run stow-deploy.sh or stow-deploy-devcontainer.sh.\n' >&2
    exit 1
fi

self=$(basename -- "$0")

# This file's own directory, not the launcher's: `scripts` is itself a stowed
# package, so a launcher is usually reached through a symlink in ~. The
# repository is the directory above the one holding this library.
sd_root=$(cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")/.." && pwd) \
    || exit 1

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
    o_bold=$'\033[1m' o_dim=$'\033[2m' o_off=$'\033[0m'
else
    o_bold='' o_dim='' o_off=''
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

sd_usage() {
    printf '%susage:%s %s [options] [package...]\n\n' "$o_bold" "$o_off" "$self"
    cat <<EOF
Deploys the packages of $sd_root with GNU stow, which
mirrors each package's files into the target directory as symlinks.

  -t, --target DIR  where to deploy. default: \$HOME
  -n, --dry-run     print what stow would do and change nothing.
  -R, --restow      re-create the links; use after a package lost a file,
                    whose link plain stow would leave behind.
  -D, --delete      remove the links instead of creating them.
  -l, --list        list the packages this script deploys, and exit.
  -f, --force       skip the check that this is the right environment.
  -h, --help        this help.

Named packages are deployed on their own; without any, every package of the
repository is. Hidden directories are packages only when a script names them,
which is how a devcontainer gets a config this machine never sees.
EOF
    printf '\n'
    local example
    for example in ${sd_examples[@]+"${sd_examples[@]}"}; do
        printf '  %s\n' "$example"
    done
}

# --- arguments -------------------------------------------------------------

sd_need_value() {
    [ -n "$2" ] || die "$1 needs a value" "e.g. $self $1 /tmp/home" "see $self --help"
}

sd_parse_args() {
    sd_target=$HOME sd_mode='' sd_dry=0 sd_list=0 sd_force=0
    while [ $# -gt 0 ]; do
        case $1 in
            -t|--target) sd_need_value "$1" "${2:-}"; sd_target=$2; shift 2 ;;
            --target=*)  sd_target=${1#*=}; sd_need_value --target "$sd_target"; shift ;;
            -n|--dry-run|--simulate) sd_dry=1; shift ;;
            -R|--restow) sd_mode=--restow; shift ;;
            -D|--delete) sd_mode=--delete; shift ;;
            -l|--list)   sd_list=1; shift ;;
            -f|--force)  sd_force=1; shift ;;
            -h|--help)   sd_usage; exit 0 ;;
            --)          shift; break ;;
            -?*)         die "unknown option $1" "see $self --help" ;;
            *)           break ;;
        esac
    done
    sd_wanted=("$@")
}

# --- environment -----------------------------------------------------------

# WSL is not a container: it has no /.dockerenv, and neither of the variables.
# DEVCONTAINER is set by the devcontainer.json of the projects here,
# REMOTE_CONTAINERS by VS Code itself.
sd_in_container() {
    [ -f /.dockerenv ] && return 0
    [ "${DEVCONTAINER:-}" = true ] && return 0
    [ -n "${REMOTE_CONTAINERS:-}" ] && return 0
    return 1
}

# Running the wrong script is not a harmless mistake: each one skips the
# packages its environment replaces, so the container script would leave this
# machine without a git config and with the container's herdr look, and the
# host script would give a container the herdr config of the host.
sd_check_where() {
    [ "$sd_force" = 1 ] && return 0
    case $sd_where in
        host)
            sd_in_container && die 'this looks like a container, not this machine' \
                'inside a devcontainer run stow-deploy-devcontainer.sh instead' \
                '--force deploys the packages of this machine anyway' ;;
        devcontainer)
            sd_in_container || die 'this does not look like a devcontainer' \
                'on this machine run stow-deploy.sh instead' \
                '--force deploys the container packages anyway' ;;
        *) die "internal error: sd_where is \"$sd_where\"" \
               'a launcher has to set it to host or devcontainer' ;;
    esac
    return 0
}

# --- packages --------------------------------------------------------------

sd_contains() {
    local needle=$1 item
    shift
    for item in "$@"; do [ "$item" = "$needle" ] && return 0; done
    return 1
}

# Fills sd_nofold and sd_folded -- two lists, because --no-folding is a
# per-invocation flag, so the two groups need one stow call each.
sd_collect() {
    local p d
    sd_nofold=() sd_folded=()

    local candidates=()
    if [ ${#sd_wanted[@]} -gt 0 ]; then
        candidates=("${sd_wanted[@]}")
        for p in "${candidates[@]}"; do
            [ -d "$sd_root/$p" ] \
                || die "$sd_root has no package $p" \
                       'run with --list to see the packages this script deploys'
            if sd_contains "$p" ${sd_exclude[@]+"${sd_exclude[@]}"}; then
                die "package $p is not deployed in a $sd_where" \
                    'it is replaced here -- see the comment in this script' \
                    "--force is not enough: name a different package"
            fi
        done
    else
        # Every visible top-level directory, which is what `stow */` means,
        # minus what this environment replaces; then the hidden packages, which
        # */ never matches and only a script that names them deploys.
        for d in "$sd_root"/*/; do
            p=$(basename -- "$d")
            sd_contains "$p" ${sd_exclude[@]+"${sd_exclude[@]}"} && continue
            candidates+=("$p")
        done
        for p in ${sd_extra[@]+"${sd_extra[@]}"}; do
            [ -d "$sd_root/$p" ] \
                || die "$sd_root has no package $p" \
                       'it belongs to this repository -- is the checkout up to date?' \
                       "git -C $sd_root pull"
            candidates+=("$p")
        done
    fi

    [ ${#candidates[@]} -gt 0 ] || die 'no packages to deploy'

    for p in "${candidates[@]}"; do
        if sd_contains "$p" ${sd_unfolded[@]+"${sd_unfolded[@]}"}; then
            sd_nofold+=("$p")
        else
            sd_folded+=("$p")
        fi
    done
}

sd_print_list() {
    printf '%s%s%s\n' "$o_bold" "$sd_root -> $sd_target" "$o_off"
    local p
    for p in ${sd_nofold[@]+"${sd_nofold[@]}"}; do
        printf '  %-24s %sunfolded%s\n' "$p" "$o_dim" "$o_off"
    done
    for p in ${sd_folded[@]+"${sd_folded[@]}"}; do
        printf '  %s\n' "$p"
    done
    if [ ${#sd_exclude[@]} -gt 0 ]; then
        printf '%snot deployed in a %s: %s%s\n' \
            "$o_dim" "$sd_where" "${sd_exclude[*]}" "$o_off"
    fi
}

# --- deploy ----------------------------------------------------------------

# One stow call per group, and the unfolded group first: it creates the real
# directories that keep the packages after it from being folded into this
# repository.
sd_stow() {
    local nofold=$1
    shift
    [ $# -gt 0 ] || return 0
    local flags=(--dir "$sd_root" --target "$sd_target")
    [ -n "$sd_mode" ] && flags+=("$sd_mode")
    [ "$nofold" = nofold ] && flags+=(--no-folding)
    [ "$sd_dry" = 1 ] && flags+=(--no --verbose)
    printf '%s+ stow %s %s%s\n' "$e_dim" "${flags[*]}" "$*" "$e_off" >&2
    stow "${flags[@]}" "$@"
}

# stow explains a conflict well; what it does not say is that it applied
# nothing at all, and what to do about the file in the way.
sd_bail() {
    printf '%serror:%s %sstow aborted: the packages it listed were not deployed%s\n' \
        "$e_red" "$e_off" "$e_bold" "$e_off" >&2
    printf '%s  a real file where a link belongs has to move aside first, e.g.%s\n' \
        "$e_dim" "$e_off" >&2
    printf '%s    mv ~/.zshrc ~/.zshrc.pre-stow.bak%s\n' "$e_dim" "$e_off" >&2
    printf '%s  a link to another package means two of them claim the same file%s\n' \
        "$e_dim" "$e_off" >&2
    exit "$1"
}

sd_main() {
    [ -n "${sd_where:-}" ] || die 'internal error: sd_where is not set' \
        'a launcher has to set sd_where before calling sd_main'
    sd_parse_args "$@"
    command -v stow >/dev/null || die 'stow is not on PATH' \
        'sudo apt install stow' 'see the "gnu stow" section of the README'
    [ -d "$sd_root" ] || die "$sd_root is not a directory"

    sd_collect
    if [ "$sd_list" = 1 ]; then
        sd_print_list
        exit 0
    fi
    sd_check_where
    [ -d "$sd_target" ] || die "the target $sd_target is not a directory" \
        'pass an existing directory with --target'

    sd_stow nofold ${sd_nofold[@]+"${sd_nofold[@]}"} || sd_bail $?
    sd_stow fold ${sd_folded[@]+"${sd_folded[@]}"} || sd_bail $?

    local count=$(( ${#sd_nofold[@]} + ${#sd_folded[@]} ))
    local verb=deployed prep=to
    [ "$sd_mode" = --delete ] && verb=removed prep=from
    if [ "$sd_dry" = 1 ]; then
        note "dry run, nothing changed: $count packages would be $verb $prep $sd_target"
    else
        note "$count packages $verb $prep $sd_target"
    fi

    # The nushell config sources generated files that stow cannot provide --
    # see the "shells" section of the README.
    if [ "$sd_dry" = 0 ] && [ "$sd_mode" != --delete ] \
        && sd_contains nushell ${sd_folded[@]+"${sd_folded[@]}"} ${sd_nofold[@]+"${sd_nofold[@]}"} \
        && command -v nu >/dev/null
    then
        note "nushell's starship and zoxide inits are generated: nu $sd_root/scripts/nu-regen-init.nu"
    fi
}
