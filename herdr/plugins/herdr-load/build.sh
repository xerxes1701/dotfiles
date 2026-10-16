#!/bin/sh
# Builds bin/herdr-load (linux-x64) and, on WSL, bin/herdr-load-win.exe
# (win-x64), each one Native AOT executable. Native AOT does not compile from
# one OS for another, so the Windows half is published by Windows' own
# dotnet.exe, from a copy under %TEMP%: a .NET build on a \\wsl$ path is slow.
# Needs the .NET 10 SDK and clang here, and on Windows the .NET 10 SDK and
# the C++ build tools (Visual Studio's "Desktop development with C++").
set -eu
cd "$(dirname "$0")"

dotnet publish herdr-load.cs -r linux-x64 -o bin

if [ -e /proc/sys/fs/binfmt_misc/WSLInterop ] || [ -e /proc/sys/fs/binfmt_misc/WSLInterop-late ]; then
    temp=$(cd /mnt/c && /mnt/c/Windows/System32/cmd.exe /d /c 'echo %TEMP%' | tr -d '\r')
    work="$(wslpath "$temp")/herdr-load-build"
    rm -rf "$work"
    mkdir -p "$work"
    cp herdr-load-win.cs "$work/"
    (cd "$work" && "/mnt/c/Program Files/dotnet/dotnet.exe" publish herdr-load-win.cs -r win-x64 -o out)
    cp "$work/out/herdr-load-win.exe" bin/
    rm -rf "$work"
fi
