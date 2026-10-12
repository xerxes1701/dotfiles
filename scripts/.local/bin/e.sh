#!/bin/sh
# Open paths in Windows Explorer -- the WSL side of `e` in the Windows
# PowerShell profile, where it is `Set-Alias e explorer`.
#
# Same obstacles as browse.sh: /etc/wsl.conf sets appendWindowsPath = false, so
# explorer.exe has to be named in full; wslpath leaves a relative path
# untranslated; a missing path makes Windows open an error dialog instead of
# failing; and explorer.exe exits 1 whatever happens.
#
# A directory opens as a folder window, a file with its default program --
# exactly what `explorer <path>` does on the Windows side. With no path the
# current directory is opened, which is what `e .` was used for anyway.
#
# POSIX sh so fish, nushell and zsh can all alias it to `e`. Outside WSL it
# falls through to xdg-open.

set -u

self=${0##*/}

err() { printf '%s: %s\n' "$self" "$*" >&2; }

usage() {
    cat <<EOF
usage: $self [--] [path...]

opens each path in windows explorer: a directory as a folder window, a file
with its default program. with no path, the current directory.

  -h, --help   this text

examples:
  $self                      the current directory
  $self Source/DotNet        a relative path (absolutised for windows)
  $self report.xml           the file, in whatever windows opens .xml with
EOF
}

while [ $# -gt 0 ]; do
    case $1 in
        -h|--help) usage; exit 0 ;;
        --)        shift; break ;;
        -*)        err "unknown option: $1"; usage >&2; exit 2 ;;
        *)         break ;;
    esac
done

[ $# -eq 0 ] && set -- .

if grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null; then
    is_wsl=1
    explorer=/mnt/c/Windows/explorer.exe
    if [ ! -x "$explorer" ]; then
        err "no executable at $explorer -- is windows interop switched off?"
        exit 1
    fi
else
    is_wsl=0
    if ! command -v xdg-open >/dev/null 2>&1; then
        err "not WSL, and no xdg-open on PATH -- nothing to open with"
        exit 1
    fi
fi

rc=0
for target in "$@"; do
    if [ ! -e "$target" ]; then
        err "no such file or directory: $target"
        rc=1
        continue
    fi

    abs=$(readlink -f -- "$target") || { err "cannot resolve: $target"; rc=1; continue; }

    if [ "$is_wsl" -eq 0 ]; then
        xdg-open "$abs" >/dev/null 2>&1 || rc=1
        continue
    fi

    # /mnt/c/... becomes C:\..., anything on the distro's own filesystem
    # \\wsl.localhost\<distro>\..., which explorer opens just as well.
    win=$(wslpath -w -- "$abs" 2>/dev/null) || {
        err "cannot translate to a windows path: $abs"
        rc=1
        continue
    }
    # Exit status is always 1, so it is not checked; stderr goes with it.
    "$explorer" "$win" >/dev/null 2>&1
done

exit "$rc"
