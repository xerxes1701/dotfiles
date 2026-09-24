#!/bin/sh
# Save the image on the clipboard as a file.
#
# Screenshots (Win+Shift+S), images copied from a browser, a copied image file
# in Explorer: all of them sit on the Windows clipboard, and none of the Linux
# clipboard tools can see it from inside WSL. xsel is installed here and only
# knows text; wl-paste and xclip need a display server that does not exist.
# The clipboard has to be read on the Windows side, which means Windows
# PowerShell -- 5.1, the one in System32, because it is on every Windows
# install and System.Windows.Forms is where the clipboard API lives.
#
# Three measured details are why this is a script and not an alias:
#
#   the target path       PowerShell writes the file itself, straight to
#                         \\wsl.localhost\<distro>\... -- wslpath -w of the
#                         absolute path -- so nothing is copied twice. The
#                         path travels as an environment variable through
#                         WSLENV instead of being spliced into the command,
#                         so quotes and spaces in a file name cannot break it.
#   the PNG stream        Snipping Tool and browsers put a "PNG" format next
#                         to the bitmap. Clipboard.GetImage() renders the
#                         bitmap and drops transparency; the stream is the
#                         original bytes and is written as-is when a .png is
#                         asked for.
#   a copied file         copying an image file in Explorer puts a file list
#                         on the clipboard, not an image. That file is copied
#                         instead of failing with "no image".
#
# Outside WSL the script reads wl-paste (Wayland) or xclip (X11), so the same
# alias works on the Linux machine these dotfiles also deploy to. There a
# non-PNG target needs ImageMagick to convert; on WSL .NET does the encoding.
#
# POSIX sh rather than a function in each shell, because it has to be
# reachable from fish, nushell and zsh (see shell-parity.sh) -- three
# dialects, one script, aliased to `pimg` in each.

set -u

self=${0##*/}

err() { printf '%s: %s\n' "$self" "$*" >&2; }

usage() {
    cat <<EOF
usage: $self [-f] [--] [path]

with no path the image is written to the current directory as
clipboard-YYYYMMDD-HHMMSS.png. a path that is an existing directory, or ends
in a slash, gets that name inside it. anything else is the file to write, and
its extension picks the format: png (also when there is none), jpg, gif, bmp,
tif. missing parent directories are created. the path written is printed on
stdout, everything else goes to stderr.

  -f, --force   overwrite an existing file
  -h, --help    this text

exit status: 0 written, 1 error, 2 usage, 3 no image on the clipboard

examples:
  $self                       ./clipboard-20260922-151430.png
  $self images/               images/clipboard-20260922-151430.png
  $self images/setup.png      exactly that file
  $self shot                  shot.png
  $self | xargs browse.sh     save it, then look at it
EOF
}

# --- options ---------------------------------------------------------------

force=0
while [ $# -gt 0 ]; do
    case $1 in
        -h|--help)  usage; exit 0 ;;
        -f|--force) force=1; shift ;;
        --)         shift; break ;;
        -*)         err "unknown option: $1"; usage >&2; exit 2 ;;
        *)          break ;;
    esac
done

if [ $# -gt 1 ]; then
    err "one path at most"
    usage >&2
    exit 2
fi

# --- the target ------------------------------------------------------------

target=${1-.}
stamp=$(date +%Y%m%d-%H%M%S)

# Auto-named targets remember it: a copied .jpg file then keeps its extension
# instead of being renamed to .png without conversion.
auto_named=0
case $target in
    */) file=${target}clipboard-$stamp.png; auto_named=1 ;;
    *)
        if [ -d "$target" ]; then
            file=$target/clipboard-$stamp.png
            auto_named=1
        else
            file=$target
        fi
        ;;
esac

base=${file##*/}
case $base in
    *.*) ext=$(printf '%s' "${base##*.}" | tr 'A-Z' 'a-z') ;;
    *)   file=$file.png; ext=png ;;
esac

# One spelling per format from here on; jpeg/tiff are accepted and kept in
# the file name, but the encoder is picked by the short form.
case $ext in
    png|gif|bmp) fmt=$ext ;;
    jpg|jpeg)    fmt=jpg ;;
    tif|tiff)    fmt=tif ;;
    *)
        err "unsupported extension .$ext -- use png, jpg, gif, bmp or tif"
        exit 1
        ;;
esac

# Remembered for the cleanup below: a file that was there before this run is
# the caller's, and a failed run must not take it away -- even with -f.
preexisted=0
if [ -e "$file" ]; then
    if [ "$force" -eq 0 ]; then
        err "$file exists -- pass -f to overwrite it"
        exit 1
    fi
    preexisted=1
fi

parent=$(dirname -- "$file")
mkdir -p -- "$parent" || { err "cannot create $parent"; exit 1; }

# readlink -f, because wslpath leaves a relative path untouched and PowerShell
# has no notion of this shell's working directory. GNU readlink resolves a
# path whose last component does not exist yet, which is the normal case here.
abs=$(readlink -f -- "$file") || { err "cannot resolve: $file"; exit 1; }

# A partial file is worse than none: remove it if anything below fails. Only
# a file this run created, though -- `pimg -f shot.png` with nothing on the
# clipboard must leave the old shot.png alone.
written=0
cleanup() {
    if [ "$written" -eq 0 ] && [ "$preexisted" -eq 0 ]; then
        rm -f -- "$abs" 2>/dev/null
    fi
}
trap cleanup EXIT

# Print the path the caller gave, not the resolved one, so `pimg images/`
# prints images/clipboard-... rather than a home-relative absolute path.
done_msg() { written=1; printf '%s\n' "$file"; }

# --- a copied file ---------------------------------------------------------
# $1 is the source in this filesystem. Shared by both platforms.

copy_source() {
    src=$1
    if [ ! -f "$src" ]; then
        err "the clipboard names a file that cannot be read from here: $src"
        return 1
    fi
    src_ext=$(printf '%s' "${src##*.}" | tr 'A-Z' 'a-z')
    case $src_ext in jpeg) src_fmt=jpg ;; tiff) src_fmt=tif ;; *) src_fmt=$src_ext ;; esac
    if [ "$src_fmt" != "$fmt" ]; then
        if [ "$auto_named" -eq 1 ]; then
            # Keep the source's format; only the name was ours to choose.
            # The .png name was never written to, so there is nothing to
            # remove -- but the new name may be somebody's file.
            file=${file%.png}.$src_ext
            abs=${abs%.png}.$src_ext
            preexisted=0
            if [ -e "$abs" ]; then
                if [ "$force" -eq 0 ]; then
                    err "$file exists -- pass -f to overwrite it"
                    return 1
                fi
                preexisted=1
            fi
        else
            err "the clipboard holds a .$src_ext file, not an image -- copying it to .$ext would not convert it"
            return 1
        fi
    fi
    # cat, not cp: a file under /mnt/c reports mode 755, and cp would keep it.
    cat -- "$src" >"$abs" || { err "cannot copy $src"; return 1; }
    done_msg
}

# --- WSL: Windows PowerShell -----------------------------------------------
# Decided the way browse.sh decides it: the kernel release is set on every
# WSL2 distribution and cannot be inherited by an environment that only looks
# like WSL.

wsl_paste() {
    ps=/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe
    if [ ! -x "$ps" ]; then
        err "no executable at $ps -- is windows interop switched off?"
        return 1
    fi

    win=$(wslpath -w -- "$abs" 2>/dev/null) || {
        err "cannot translate to a windows path: $abs"
        return 1
    }

    # Runs on the Windows side. Reads its two inputs from the environment
    # (see WSLENV below) and reports with the exit status:
    #   0  written          3  nothing usable on the clipboard
    #   4  a file list: its one path is printed on stdout
    #   1  anything else, with .NET's message on stderr
    # -Sta, because the clipboard is a COM object that wants a single-threaded
    # apartment; without it GetDataObject() returns nothing.
    script='
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [Text.Encoding]::UTF8
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$target = $env:PIMG_TARGET
$fmt = $env:PIMG_FORMAT
# Opening the clipboard fails with CLIPBRD_E_CANT_OPEN while another process
# holds it -- a clipboard manager, or the app that has just written to it. It
# clears within milliseconds, so retry briefly before giving up.
$cb = $null
for ($try = 0; $try -lt 10; $try++) {
    try { $cb = [Windows.Forms.Clipboard]::GetDataObject(); break }
    catch { Start-Sleep -Milliseconds 150 }
}
if ($cb -eq $null) {
    [Console]::Error.WriteLine("the clipboard stayed locked by another process")
    exit 1
}

# 1. The original PNG bytes, when there are any and PNG is what is wanted.
if ($fmt -eq "png" -and $cb.GetDataPresent("PNG")) {
    $s = $cb.GetData("PNG")
    if ($s -is [IO.Stream]) {
        $f = [IO.File]::Create($target)
        try { $s.Position = 0; $s.CopyTo($f) } finally { $f.Dispose() }
        exit 0
    }
}

# 2. A bitmap, encoded by .NET into whatever was asked for.
if ($cb.ContainsImage()) {
    $img = [Windows.Forms.Clipboard]::GetImage()
    if ($img -eq $null) { exit 3 }
    switch ($fmt) {
        "png" { $img.Save($target, [Drawing.Imaging.ImageFormat]::Png) }
        "gif" { $img.Save($target, [Drawing.Imaging.ImageFormat]::Gif) }
        "bmp" { $img.Save($target, [Drawing.Imaging.ImageFormat]::Bmp) }
        "tif" { $img.Save($target, [Drawing.Imaging.ImageFormat]::Tiff) }
        "jpg" {
            # JPEG has no alpha; flatten onto white first or GDI+ paints the
            # transparent parts black.
            $flat = New-Object Drawing.Bitmap $img.Width, $img.Height, ([Drawing.Imaging.PixelFormat]::Format24bppRgb)
            $g = [Drawing.Graphics]::FromImage($flat)
            $g.Clear([Drawing.Color]::White)
            $g.DrawImage($img, 0, 0, $img.Width, $img.Height)
            $g.Dispose()
            $codec = [Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/jpeg" }
            $p = New-Object Drawing.Imaging.EncoderParameters 1
            $p.Param[0] = New-Object Drawing.Imaging.EncoderParameter ([Drawing.Imaging.Encoder]::Quality, [long]92)
            $flat.Save($target, $codec, $p)
        }
    }
    exit 0
}

# 3. A copied file. Only a single one makes sense for a single target.
if ($cb.ContainsFileDropList()) {
    $files = $cb.GetFileDropList()
    if ($files.Count -eq 1) {
        Write-Output $files[0]
        exit 4
    }
    [Console]::Error.WriteLine("the clipboard holds $($files.Count) files, not one image")
    exit 1
}
exit 3
'

    out=$(mktemp) || { err "cannot create a temporary file"; return 1; }
    # WSLENV names the variables that cross into the Windows process. Append,
    # not replace: the user's own WSLENV may carry other variables.
    PIMG_TARGET=$win PIMG_FORMAT=$fmt \
    WSLENV="${WSLENV:+$WSLENV:}PIMG_TARGET:PIMG_FORMAT" \
        "$ps" -NoProfile -NonInteractive -Sta -Command "$script" >"$out" 2>"$out.err"
    rc=$?
    # Windows line endings, and .NET error output is verbose: the first line
    # carries the message, the rest is a stack of positions.
    tr -d '\r' <"$out" >"$out.lf"
    case $rc in
        0) rm -f -- "$out" "$out.err" "$out.lf"; done_msg; return 0 ;;
        3) rm -f -- "$out" "$out.err" "$out.lf"
           err "no image on the clipboard"
           return 3 ;;
        4) winfile=$(head -n 1 -- "$out.lf")
           rm -f -- "$out" "$out.err" "$out.lf"
           src=$(wslpath -u -- "$winfile" 2>/dev/null) || {
               err "cannot translate the copied file's path: $winfile"
               return 1
           }
           copy_source "$src" ;;
        *) msg=$(tr -d '\r' <"$out.err" | grep -v '^\s*$' | head -n 1)
           rm -f -- "$out" "$out.err" "$out.lf"
           err "powershell failed (exit $rc)${msg:+: $msg}"
           return 1 ;;
    esac
}

# --- Linux: wl-paste or xclip ----------------------------------------------

linux_paste() {
    if [ -n "${WAYLAND_DISPLAY-}" ] && command -v wl-paste >/dev/null 2>&1; then
        types=$(wl-paste --list-types 2>/dev/null)
        read_type() { wl-paste --no-newline --type "$1"; }
    elif [ -n "${DISPLAY-}" ] && command -v xclip >/dev/null 2>&1; then
        types=$(xclip -selection clipboard -t TARGETS -o 2>/dev/null)
        read_type() { xclip -selection clipboard -t "$1" -o; }
    else
        err "not WSL, and neither wl-paste (Wayland) nor xclip (X11) is usable here"
        return 1
    fi

    # A copied file shows up as text/uri-list, which both tools serve.
    if ! printf '%s\n' "$types" | grep -q '^image/'; then
        if printf '%s\n' "$types" | grep -q '^text/uri-list$'; then
            uri=$(read_type text/uri-list | head -n 1 | tr -d '\r')
            case $uri in
                file://*)
                    src=$(printf '%s' "${uri#file://}" | sed 's/%\([0-9A-Fa-f][0-9A-Fa-f]\)/\\x\1/g')
                    src=$(printf "$src")
                    copy_source "$src"
                    return $?
                    ;;
            esac
        fi
        err "no image on the clipboard"
        return 3
    fi

    # Prefer the lossless one; otherwise take whatever image type is offered.
    if printf '%s\n' "$types" | grep -qx 'image/png'; then
        mime=image/png
    else
        mime=$(printf '%s\n' "$types" | grep '^image/' | head -n 1)
    fi
    case $mime in
        image/png)  have=png ;;
        image/jpeg) have=jpg ;;
        image/gif)  have=gif ;;
        image/bmp)  have=bmp ;;
        image/tiff) have=tif ;;
        *)          have= ;;
    esac

    if [ "$have" = "$fmt" ]; then
        read_type "$mime" >"$abs" || { err "cannot read $mime from the clipboard"; return 1; }
        [ -s "$abs" ] || { err "the clipboard offered $mime but delivered nothing"; return 1; }
        done_msg
        return 0
    fi

    # Format conversion is ImageMagick's job, not this script's.
    if command -v magick >/dev/null 2>&1; then convert=magick
    elif command -v convert >/dev/null 2>&1; then convert=convert
    else
        err "the clipboard offers $mime and .$ext was asked for -- converting needs ImageMagick"
        return 1
    fi
    tmp=$(mktemp) || { err "cannot create a temporary file"; return 1; }
    read_type "$mime" >"$tmp" || { rm -f -- "$tmp"; err "cannot read $mime from the clipboard"; return 1; }
    "$convert" "$tmp" "$fmt:$abs" || { rm -f -- "$tmp"; err "conversion to $fmt failed"; return 1; }
    rm -f -- "$tmp"
    done_msg
}

# --- dispatch --------------------------------------------------------------

if grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null; then
    wsl_paste
else
    linux_paste
fi
