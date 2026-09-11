#!/bin/sh
# Open files, URLs or piped content in a real browser.
#
# On WSL there is no Linux browser to reach for: www-browser is lynx, `open` is
# a symlink to xdg-open, and no x-www-browser alternative is registered. The
# only real browser lives on the Windows side, and /etc/wsl.conf sets
# appendWindowsPath = false, so explorer.exe has to be named in full and the
# path handed to it has to be translated first.
#
# Four measured details make that more than a one-line alias:
#
#   wslpath -w sb.html       -> sb.html       relative paths are NOT translated,
#                                             and a relative path is exactly
#                                             what `fzf` prints
#   wslpath -w https://x/    -> https\x\      a URL has to bypass wslpath
#   wslpath -w /no/such.html -> a path        existence is ours to check, or
#                                             Windows opens an error dialog
#   explorer.exe <anything>  -> exit 1        always, even on success: its
#                                             status carries no information
#
# POSIX sh rather than a function in each shell, because the same opener has to
# be reachable from fish, nushell and zsh (see shell-parity.sh) -- three
# dialects, one script, aliased to `br` in each. Outside WSL it falls through to
# xdg-open, so the same alias works on the Linux machine these dotfiles also
# deploy to.

set -u

self=${0##*/}

err() { printf '%s: %s\n' "$self" "$*" >&2; }

usage() {
    cat <<EOF
usage: $self [-c] [--] [target...]
       <command> | $self [-c]

targets are files, directories or URLs. with no target, stdin is read: lines
that are all existing paths or URLs are opened as such, anything else is
treated as content, written to a temporary file and opened in the browser.

  -c, --content   read stdin as content even if it looks like a list of paths
  -h, --help      this text

examples:
  $self lessons/01.html            a relative path (absolutised for windows)
  $self main.pdf https://typst.app several targets at once
  fd -e html | fzf | $self         the selected file
  curl -s https://example.com | $self       the fetched page
  git log --oneline | $self -c     text, wrapped in <pre> and rendered
EOF
}

# --- options ---------------------------------------------------------------

force_content=0
while [ $# -gt 0 ]; do
    case $1 in
        -h|--help)    usage; exit 0 ;;
        -c|--content) force_content=1; shift ;;
        --)           shift; break ;;
        -)            break ;;          # explicit stdin: a target, not an option
        -*)           err "unknown option: $1"; usage >&2; exit 2 ;;
        *)            break ;;
    esac
done

# --- the opener ------------------------------------------------------------
# Decided once. $WSL_DISTRO_NAME and /proc/sys/fs/binfmt_misc/WSLInterop would
# also do, but the kernel release is set on every WSL2 distribution and cannot
# be inherited by a child environment that only looks like WSL.

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

# One prepared target: a URL, or a path in whichever flavour the opener wants.
open_it() {
    if [ "$is_wsl" -eq 1 ]; then
        # Its exit status is 1 whatever happens, so it is deliberately not
        # checked; stderr is dropped for the same reason.
        "$explorer" "$1" >/dev/null 2>&1
        return 0
    fi
    xdg-open "$1" >/dev/null 2>&1
}

# --- one target ------------------------------------------------------------

open_target() {
    case $1 in
        http://*|https://*|file://*)
            open_it "$1"
            return 0
            ;;
    esac

    if [ ! -e "$1" ]; then
        err "no such file: $1"
        return 1
    fi

    # readlink -f, because wslpath leaves a relative path untouched and
    # explorer.exe has no notion of this shell's working directory.
    abs=$(readlink -f -- "$1") || { err "cannot resolve: $1"; return 1; }

    if [ "$is_wsl" -eq 1 ]; then
        win=$(wslpath -w -- "$abs" 2>/dev/null) || {
            err "cannot translate to a windows path: $abs"
            return 1
        }
        open_it "$win"
    else
        open_it "$abs"
    fi
}

# --- content ---------------------------------------------------------------

# Name the extension the content deserves, from its first bytes. The extension
# is what decides which program Windows hands the file to, so plain text must
# not stay .txt -- that opens Notepad, and this command is called browse.
sniff() {
    head=$(head -c 512 -- "$1" 2>/dev/null | tr -d '\000')
    case $head in
        %PDF*) printf pdf; return 0 ;;
    esac
    case $(printf '%s' "$head" | tr 'A-Z' 'a-z') in
        *'<!doctype html'*|*'<html'*) printf html ;;
        *'<svg'*)                     printf svg ;;
        *)                            printf txt ;;
    esac
}

# $1 holds the content. The temporary file is deliberately never cleaned up
# here: the opener returns long before the browser has read the file, so a trap
# would delete it out from under a still-loading tab. /tmp is the janitor.
open_content() {
    d=$(mktemp -d) || { err "cannot create a temporary directory"; return 1; }
    case $(sniff "$1") in
        pdf)  out=$d/browse.pdf;  cp -- "$1" "$out" ;;
        html) out=$d/browse.html; cp -- "$1" "$out" ;;
        svg)  out=$d/browse.svg;  cp -- "$1" "$out" ;;
        *)    out=$d/browse.html
              {
                  printf '%s\n' '<!DOCTYPE html><html><head><meta charset="utf-8">'
                  printf '%s\n' '<title>stdin</title></head><body>'
                  printf '%s\n' '<pre style="white-space:pre-wrap;word-break:break-word;font:13px/1.55 ui-monospace,Consolas,monospace;margin:1.5rem">'
                  sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -- "$1"
                  printf '%s\n' '</pre></body></html>'
              } >"$out" || { err "cannot write $out"; return 1; }
              ;;
    esac
    open_target "$out"
}

# --- stdin -----------------------------------------------------------------

handle_stdin() {
    d=$(mktemp -d) || { err "cannot create a temporary directory"; return 1; }
    buf=$d/stdin
    cat >"$buf"

    if [ ! -s "$buf" ]; then
        err "nothing on stdin"
        return 1
    fi

    if [ "$force_content" -eq 1 ]; then
        open_content "$buf"
        return $?
    fi

    # Paths only if every non-empty line is one. `|| [ -n "$line" ]` catches a
    # last line without a trailing newline, which is what printf and a few
    # generators produce.
    all_paths=1
    while IFS= read -r line || [ -n "$line" ]; do
        [ -n "$line" ] || continue
        case $line in
            http://*|https://*|file://*) continue ;;
        esac
        [ -e "$line" ] && continue
        all_paths=0
        # The price of deciding automatically: a mistyped path is content, and
        # would otherwise be rendered without a word. Only say so when the line
        # really does look like a path -- a slash, no markup, no spaces -- and
        # its parent directory exists, which is what a typo in a file name
        # looks like. A closing HTML tag holds a slash too, and content must
        # not be nagged about.
        case $line in
            *'<'*|*'>'*|*' '*|*"	"*) ;;
            */*)
                parent=${line%/*}
                [ -n "$parent" ] || parent=/
                [ -d "$parent" ] && err "note: \"$line\" looks like a path but does not exist -- reading stdin as content"
                ;;
        esac
        break
    done <"$buf"

    if [ "$all_paths" -eq 1 ]; then
        rc=0
        while IFS= read -r line || [ -n "$line" ]; do
            [ -n "$line" ] || continue
            open_target "$line" || rc=1
        done <"$buf"
        return "$rc"
    fi

    open_content "$buf"
}

# --- dispatch --------------------------------------------------------------

rc=0

if [ $# -eq 0 ]; then
    if [ -t 0 ]; then
        err "no target, and stdin is a terminal"
        usage >&2
        exit 2
    fi
    handle_stdin || rc=1
else
    for target in "$@"; do
        if [ "$target" = "-" ]; then
            handle_stdin || rc=1
        else
            open_target "$target" || rc=1
        fi
    done
fi

exit "$rc"
