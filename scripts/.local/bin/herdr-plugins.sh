#!/usr/bin/env bash
# Link, build and start the herdr plugins that live in this repository.
#
# herdr/plugins is kept out of stow (herdr/.stow-local-ignore): herdr does not
# read plugins out of its config directory, it registers each one with
# `herdr plugin link <dir>` and runs it from where it lies. So deploying the
# herdr package puts none of them in place, and this script is the step that
# does, once per machine:
#
#   1. links every directory under herdr/plugins with a herdr-plugin.toml whose
#      platforms include this one, and enables it if it was linked disabled;
#   2. runs a plugin's build.sh when it has one and its bin/ is missing or
#      older than its sources -- herdr-load is a Native AOT executable, and its
#      startup hook refuses to run until it is built;
#   3. has a running server reread its config, and invokes the restart action
#      of each plugin that declares a startup hook. Startup hooks run when a
#      server starts, not when a plugin is linked or rebuilt, so without this a
#      running session goes on without the plugin, or with the old build.
#
# It is idempotent, so it is also the thing to run after a `git pull` that
# changed a plugin. Naming plugins limits it to those.
#
# Usage: herdr-plugins.sh [-n] [--rebuild] [plugin...]
#
# Smart-splits.nvim's herdr plugin is not one of these: its checkout belongs
# to nvim, and nav-setup.sh links it.
set -uo pipefail

self=${0##*/}
usage() {
    cat <<EOF
usage: $self [options] [plugin...]

Link, build and start the herdr plugins under herdr/plugins.

  -n, --dry-run   print what would be done, do nothing.
  --rebuild       run every build.sh, even where bin/ is up to date.
  -h, --help      this.
EOF
    exit "${1:-0}"
}

dry=0 rebuild=0
while [ $# -gt 0 ]; do
    case $1 in
        -n | --dry-run) dry=1; shift ;;
        --rebuild)      rebuild=1; shift ;;
        -h | --help)    usage ;;
        --)             shift; break ;;
        -?*)            printf '%s: unknown option %s\n' "$self" "$1" >&2; usage 2 >&2 ;;
        *)              break ;;
    esac
done
wanted=("$@")

# readlink -f, so this still finds the repository when the script is reached
# through the symlink that stowing `scripts` puts in ~/.local/bin. This file
# lives in scripts/.local/bin, three levels below the repository.
root=$(cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")/../../.." && pwd) \
    || exit 1
plugins=$root/herdr/plugins

if ! command -v herdr >/dev/null 2>&1; then
    printf 'no herdr on PATH -- install-tools.sh herdr\n'
    exit 1
fi

# The names herdr-plugin.toml's `platforms` uses.
case $(uname -s) in
    Linux)                      platform=linux ;;
    Darwin)                     platform=macos ;;
    MINGW* | MSYS* | CYGWIN*)   platform=windows ;;
    *)                          platform=unknown ;;
esac

# The command goes to stderr, so a caller can silence what it prints without
# silencing the line that says what ran.
run() {
    printf '  $ %s\n' "$*" >&2
    [ "$dry" = 1 ] || "$@"
}

# What a step reports once it has happened; a dry run has nothing to report.
did() { [ "$dry" = 1 ] || printf '  %-12s %s\n' "$1" "$2"; }

# One top-level key of a manifest, as a bare string: `id = "x"` gives x, and
# `platforms = ["linux", "macos"]` gives "linux", "macos".
manifest_value() {
    sed -n "s/^$2[[:space:]]*=[[:space:]]*//p" "$1" | head -n 1 | tr -d '"[]'
}

server_up=0
herdr status server >/dev/null 2>&1 && server_up=1

status=0
restart=()

for dir in "$plugins"/*/; do
    dir=${dir%/}
    manifest=$dir/herdr-plugin.toml
    [ -f "$manifest" ] || continue
    id=$(manifest_value "$manifest" id)
    [ -n "$id" ] || id=${dir##*/}

    if [ ${#wanted[@]} -gt 0 ]; then
        case " ${wanted[*]} " in *" $id "* | *" ${dir##*/} "*) ;; *) continue ;; esac
    fi

    printf '== %s ==\n' "$id"

    platforms=$(manifest_value "$manifest" platforms)
    if [ -n "$platforms" ] && [[ ", $platforms," != *", $platform,"* ]]; then
        printf '  skipped      for %s only, this is %s\n\n' "$platforms" "$platform"
        continue
    fi

    # --- 1. link ------------------------------------------------------------
    # `plugin list` prints one line per plugin:
    #   - herdr-load (herdr-load) enabled [local:/home/.../herdr-load]
    line=$(herdr plugin list 2>/dev/null | grep -F -- "- $id (" || true)
    if [ -z "$line" ]; then
        run herdr plugin link --enabled "$dir" || { status=1; printf '\n'; continue; }
        did link linked
    elif [[ $line != *"[local:$dir]"* ]]; then
        # Linked from another checkout, or installed from GitHub: this one is
        # meant to win, or the script would not have been run from it.
        printf '  link         points elsewhere, relinking: %s\n' "${line#*[}"
        run herdr plugin unlink "$id" && run herdr plugin link --enabled "$dir" \
            || { status=1; printf '\n'; continue; }
    elif [[ $line == *" disabled "* ]]; then
        run herdr plugin enable "$id" && did link enabled || status=1
    else
        printf '  link         already linked and enabled\n'
    fi

    # --- 2. build -----------------------------------------------------------
    # bin/ is touched after every build, so a source newer than it -- edited,
    # or rewritten by a pull -- is what makes a build due.
    if [ -x "$dir/build.sh" ]; then
        due=$rebuild
        if [ ! -d "$dir/bin" ]; then
            due=1
        elif [ -n "$(find "$dir" -path "$dir/bin" -prune -o -type f -newer "$dir/bin" -print -quit)" ]; then
            due=1
        fi
        if [ "$due" = 1 ]; then
            if run "$dir/build.sh"; then
                [ "$dry" = 1 ] || touch "$dir/bin"
                did build done
            else
                printf '  build        FAILED -- install-tools.sh lists what %s needs\n' "$id"
                status=1
                printf '\n'
                continue
            fi
        else
            printf '  build        up to date\n'
        fi
    fi

    # --- 3. collected for the restart below ---------------------------------
    if grep -q '^\[\[startup\]\]' "$manifest"; then
        if grep -q '^id[[:space:]]*=[[:space:]]*"restart"' "$manifest"; then
            restart+=("$id")
        else
            printf '  startup      runs when the server next starts (no restart action)\n'
        fi
    fi
    printf '\n'
done

# --- the running server ------------------------------------------------------
# Nothing to do without one: the next server to start runs the startup hooks
# itself.
if [ "$server_up" = 0 ]; then
    printf 'no herdr server running -- the plugins start with the next one.\n'
    exit "$status"
fi

printf '== server ==\n'
run herdr server reload-config >/dev/null || status=1
for id in ${restart[@]+"${restart[@]}"}; do
    if run herdr plugin action invoke restart --plugin "$id" >/dev/null; then
        did "$id" restarted
    else
        printf '  %-12s restart FAILED -- herdr plugin log list\n' "$id" "$id"
        status=1
    fi
done

exit "$status"
