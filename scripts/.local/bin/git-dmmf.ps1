#!/usr/bin/env pwsh
# Pick a file changed since the merge base with the main branch, with the diff
# in the preview window. The Windows twin of the `dmmf` git alias body.
#
# The alias dispatches here on MINGW because a git `!` alias always runs in
# Git's MSYS sh, and fzf.exe started from that sh exits on the arrow keys and
# pipes back an empty result (junegunn/fzf#3346); ctrl-n and ctrl-p still work
# there, but the arrows are what one reaches for. Started from pwsh, fzf gets
# the console it expects and both work.
#
# --with-shell keeps the preview in sh, so $FZF_PREVIEW_COLUMNS expands the way
# it does on linux. fzf's default child shell on Windows is cmd.exe, which
# passes the name through literally and makes delta reject the width.
#
# Usage: git dmmf   (via the alias; takes no arguments)
$ErrorActionPreference = 'Stop'

git dmm --name-only |
    fzf -m --with-shell 'sh -c' `
        --preview 'git dmm -- {} | delta --width $FZF_PREVIEW_COLUMNS' `
        --preview-window 'up,80%'
