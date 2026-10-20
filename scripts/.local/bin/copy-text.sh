#!/bin/sh
# Put text on the clipboard: the arguments, joined by spaces, or else stdin.
#
# The other direction of paste-image.sh, and decided the same way: on WSL the
# text goes to the Windows clipboard, through clip.exe. Elsewhere it goes
# through wl-copy (Wayland), or xclip or xsel (X11). Where none of them can
# reach a clipboard -- ssh, a devcontainer -- the terminal is asked to set it
# with OSC 52.
#
# Two measured details:
#
#   UTF-16LE for clip.exe   clip.exe reads its input in the OEM code page, so
#                           UTF-8 arrives garbled: "Größe" lands on the
#                           clipboard as "Gr├Â├ƒe". UTF-16LE without a BOM
#                           comes through intact, and clip.exe takes ~80 ms
#                           where starting PowerShell takes ~300.
#   trailing newlines       are dropped, the way $(...) drops them. `pwd |
#                           copy-text.sh`, pasted into a prompt, then waits
#                           for Enter instead of running at once.
#
# POSIX sh for the same reason as paste-image.sh: one script for fish,
# nushell, zsh and bash. Each of them has a `cpl` that feeds it the previous
# command line; that part cannot be shared, because every shell keeps its
# history its own way.

set -u

self=${0##*/}

err() { printf '%s: %s\n' "$self" "$*" >&2; }

usage() {
    cat <<EOF
usage: $self [--] text...
       <command> | $self

the arguments, joined by single spaces, or with none stdin, go to the
clipboard, without trailing newlines. on wsl that is the windows clipboard;
on linux the wayland or x11 one; anywhere else the terminal is asked to set
it (osc 52), which it may ignore.

  -h, --help    this text

exit status: 0 copied, 1 error, 2 usage

examples:
  $self 'git status --short'
  pwd | $self
  cpl                         the previous command line, in every shell
EOF
}

# --- options ---------------------------------------------------------------

while [ $# -gt 0 ]; do
    case $1 in
        -h|--help) usage; exit 0 ;;
        --)        shift; break ;;
        -*)        err "unknown option: $1"; usage >&2; exit 2 ;;
        *)         break ;;
    esac
done

# --- the text --------------------------------------------------------------

if [ $# -gt 0 ]; then
    text=$*
elif [ -t 0 ]; then
    # Waiting on a terminal for text nobody is about to type helps no one.
    err "no text -- pass it as arguments or on stdin"
    usage >&2
    exit 2
else
    text=$(cat) || { err "cannot read stdin"; exit 1; }
fi

if [ -z "$text" ]; then
    err "nothing to copy"
    exit 1
fi

# --- WSL: clip.exe ---------------------------------------------------------
# The kernel release says WSL, as in paste-image.sh and browse.sh. A
# devcontainer on a WSL machine shares that kernel but has no /mnt/c, so
# clip.exe has to be there too -- otherwise the container falls through to
# OSC 52 below.

clip=/mnt/c/Windows/System32/clip.exe

wsl_copy() {
    printf '%s' "$text" | iconv -f UTF-8 -t UTF-16LE | "$clip" || {
        err "clip.exe failed -- is windows interop switched off?"
        return 1
    }
}

# --- OSC 52: the terminal --------------------------------------------------
# There is no answer to wait for, so a terminal that ignores the sequence
# looks exactly like one that took it. tmux swallows it unless set-clipboard
# is on, so inside tmux it goes to the terminal tmux runs in, as
# fish_clipboard_copy does it.

osc52_copy() {
    tty=/dev/tty
    if [ -n "${TMUX-}" ]; then
        tty=$(tmux display-message -p '#{client_tty}' 2>/dev/null)
        # A detached session has no client, and then no tty to name.
        [ -n "$tty" ] || tty=/dev/tty
    fi
    encoded=$(printf '%s' "$text" | base64 | tr -d '\n')
    { printf '\033]52;c;%s\a' "$encoded" >"$tty"; } 2>/dev/null || {
        err "no wl-copy, xclip or xsel here, and no terminal to ask"
        return 1
    }
}

# --- dispatch --------------------------------------------------------------
# stdout to /dev/null for the X11 and Wayland tools: they stay behind in the
# background to serve the selection, and an inherited stdout would keep
# `x=$(... | copy-text.sh)` waiting for them to exit.

if grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null \
   && [ -x "$clip" ]; then
    wsl_copy
elif [ -n "${WAYLAND_DISPLAY-}" ] && command -v wl-copy >/dev/null 2>&1; then
    printf '%s' "$text" | wl-copy >/dev/null
elif [ -n "${DISPLAY-}" ] && command -v xclip >/dev/null 2>&1; then
    printf '%s' "$text" | xclip -selection clipboard >/dev/null
elif [ -n "${DISPLAY-}" ] && command -v xsel >/dev/null 2>&1; then
    printf '%s' "$text" | xsel --clipboard --input >/dev/null
else
    osc52_copy
fi
