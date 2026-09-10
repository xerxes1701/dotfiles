#!/usr/bin/env bash
# Install the Claude Code plugins that the stowed settings.json declares.
#
# The `claude` package carries ~/.claude/settings.json, and that file already
# names both halves of a plugin: `extraKnownMarketplaces` says where it comes
# from and `enabledPlugins` says it should be on. What it does not do is put it
# on the machine. Since Claude Code 2.1.195 a plugin from an external source
# that only a settings file enables is reported as not installed and waits for
# a `claude plugin install`, and the CLI does not materialize a marketplace it
# has only read about either -- `claude plugin marketplace add` has to run.
#
# So this is the "once per machine" step for the claude package, the way
# nu-regen-init.nu is for nushell: it reads the two tables out of the stowed
# settings.json and runs the two commands per plugin. Nothing is hardcoded
# here, so declaring another plugin in settings.json is the only edit a second
# one needs.
#
# Both commands are idempotent and neither rewrites settings.json, so a re-run
# after a `git pull` costs a marketplace refresh and nothing else.

set -uo pipefail

self=$(basename -- "$0")

# readlink -f, so this still finds the repository when the script is reached
# through the symlink that stowing `scripts` puts in ~/.local/bin. This file
# lives in scripts/.local/bin, three levels below the repository.
root=$(cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")/../../.." && pwd) \
    || exit 1

# The packaged copy, not ~/.claude/settings.json: this reads what the
# repository declares, which is the point on a machine where the package has
# not been stowed yet.
settings=$root/claude/.claude/settings.json

# Same rule as the other scripts here: colors for a terminal only, and never
# against NO_COLOR (https://no-color.org) or TERM=dumb.
if [ -z "${NO_COLOR:-}" ] && [ "${TERM:-dumb}" != dumb ] && { [ -t 1 ] || [ -t 2 ]; }; then
    c_bold=$(printf '\033[1m');         c_dim=$(printf '\033[2m')
    c_ok=$(printf '\033[1;38;5;108m');  c_bad=$(printf '\033[1;38;5;174m')
    c_off=$(printf '\033[0m')
else
    c_bold= c_dim= c_ok= c_bad= c_off=
fi

die() {
    printf '%s%s: error:%s %s\n' "$c_bad" "$self" "$c_off" "$1" >&2
    shift
    for hint in "$@"; do printf '%s  %s%s\n' "$c_dim" "$hint" "$c_off" >&2; done
    exit 1
}

usage() {
    cat <<EOF
usage: $self [-n] [-h]

Install the Claude Code plugins declared in the claude package's settings.json.

  -n, --dry-run  print the commands, run nothing
  -h, --help     this

Run it once per machine after $c_bold\`stow-deploy.sh\`$c_off, then restart Claude Code.
EOF
    exit 0
}

dry=0
for arg in "$@"; do
    case $arg in
        -n | --dry-run) dry=1 ;;
        -h | --help) usage ;;
        *) die "unknown argument: $arg" "$self --help" ;;
    esac
done

command -v claude >/dev/null 2>&1 \
    || die 'claude is not on PATH' \
           'https://code.claude.com/docs/en/setup'
command -v jq >/dev/null 2>&1 || die 'jq is not on PATH' 'sudo apt install jq'
[ -r "$settings" ] || die "cannot read $settings" \
    'it belongs to this repository -- is the checkout up to date?' \
    "git -C $root pull"

# --- what settings.json asks for -------------------------------------------

# A marketplace entry is keyed by its name and holds the source Claude Code
# clones from. Only the `github` shape is emitted as owner/repo; anything else
# is passed through as its url or path, which is what `marketplace add` takes.
mapfile -t markets < <(
    jq -r '
        (.extraKnownMarketplaces // {}) | to_entries[]
        | .key + "\t" + (
            if .value.source.source == "github" then .value.source.repo
            else (.value.source.url // .value.source.path // "") end
          )
    ' "$settings"
) || die "could not parse $settings"

# `false` disables a plugin without removing the declaration, so filter on the
# value rather than taking every key.
mapfile -t plugins < <(
    jq -r '(.enabledPlugins // {}) | to_entries[] | select(.value) | .key' "$settings"
) || die "could not parse $settings"

if [ ${#markets[@]} -eq 0 ] && [ ${#plugins[@]} -eq 0 ]; then
    printf '%snothing declared in %s%s\n' "$c_dim" "$settings" "$c_off"
    exit 0
fi

run() {
    printf '%s+ %s%s\n' "$c_dim" "$*" "$c_off" >&2
    [ "$dry" = 1 ] && return 0
    "$@"
}

status=0

# --- marketplaces first, then the plugins that come out of them ------------

printf '%s== marketplaces ==%s\n' "$c_bold" "$c_off"
for entry in ${markets[@]+"${markets[@]}"}; do
    name=${entry%%$'\t'*}
    source=${entry#*$'\t'}
    if [ -z "$source" ]; then
        printf '  %s%-24s no source Claude Code can clone -- add it by hand%s\n' \
            "$c_bad" "$name" "$c_off"
        status=1
        continue
    fi
    run claude plugin marketplace add "$source" || status=1
done

printf '\n%s== plugins ==%s\n' "$c_bold" "$c_off"
# `plugin list` names each installed plugin as plugin@marketplace, the same
# identifier enabledPlugins is keyed by, so an install that already happened is
# a substring away and costs no network.
installed=$(claude plugin list 2>/dev/null)
for plugin in ${plugins[@]+"${plugins[@]}"}; do
    if printf '%s\n' "$installed" | grep -qF -- "$plugin"; then
        printf '  %s%-32s already installed%s\n' "$c_dim" "$plugin" "$c_off"
        continue
    fi
    run claude plugin install "$plugin" || status=1
done

if [ "$dry" = 1 ]; then
    printf '\n%sdry run: nothing was installed%s\n' "$c_dim" "$c_off"
elif [ "$status" = 0 ]; then
    printf '\n%sok%s -- restart Claude Code, or run %s/reload-plugins%s in a session\n' \
        "$c_ok" "$c_off" "$c_bold" "$c_off"
fi

exit "$status"
