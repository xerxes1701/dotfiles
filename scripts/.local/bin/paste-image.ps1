#!/usr/bin/env pwsh
# Save the image on the clipboard as a file.
#
# The Windows twin of paste-image.sh, for Claude Code on Windows and anything
# else that cannot run a bash script. The .sh reads the Windows clipboard from
# WSL by handing a PowerShell script to Windows PowerShell; this is that
# script standing on its own, with the same arguments, output and exit codes.
# See the header of the .sh for why the PNG stream comes first and why a
# copied file is copied.
#
# Usage: paste-image.ps1 [-Force] [path]
#
# With no path the image is written to the current directory as
# clipboard-YYYYMMDD-HHMMSS.png. A path that is an existing directory, or ends
# in a slash, gets that name inside it. Anything else is the file to write,
# and its extension picks the format: png (also when there is none), jpg,
# gif, bmp, tif. Missing parent directories are created. The path written is
# printed on stdout, everything else goes to stderr.
#
# Exit status: 0 written, 1 error, 3 no image on the clipboard.
param(
    [Parameter(Position = 0)][string]$Path = '.',
    [Alias('f')][switch]$Force
)

# The clipboard is a COM object that wants a single-threaded apartment;
# without one GetDataObject() returns nothing. Windows PowerShell runs in one,
# PowerShell 7 not always, so that case starts Windows PowerShell over.
if ([Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA') {
    $again = @('-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-Sta', '-File', $PSCommandPath, $Path)
    if ($Force) { $again += '-Force' }
    & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" @again
    exit $LASTEXITCODE
}

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

function Fail([string]$Message, [int]$Code = 1) {
    [Console]::Error.WriteLine("paste-image.ps1: $Message")
    exit $Code
}

# --- the target ------------------------------------------------------------

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
# Auto-named targets remember it: a copied .jpg file then keeps its extension
# instead of being renamed to .png without conversion.
$autoNamed = $false
if ($Path -match '[\\/]$') {
    $file = "${Path}clipboard-$stamp.png"
    $autoNamed = $true
} elseif (Test-Path -LiteralPath $Path -PathType Container) {
    $file = Join-Path $Path "clipboard-$stamp.png"
    $autoNamed = $true
} else {
    $file = $Path
}

$leaf = Split-Path -Leaf $file
if ($leaf -notmatch '\.') {
    $file = "$file.png"
    $leaf = "$leaf.png"
}
$ext = ($leaf -replace '^.*\.', '').ToLowerInvariant()

# One spelling per format from here on; jpeg/tiff are accepted and kept in
# the file name, but the encoder is picked by the short form.
$fmt = switch ($ext) {
    { $_ -in 'png', 'gif', 'bmp' } { $ext }
    { $_ -in 'jpg', 'jpeg' } { 'jpg' }
    { $_ -in 'tif', 'tiff' } { 'tif' }
    default { Fail "unsupported extension .$ext -- use png, jpg, gif, bmp or tif" }
}

# The resolved path, because .NET has no notion of this shell's location.
$abs = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($file)

# Remembered for the cleanup below: a file that was there before this run is
# the caller's, and a failed run must not take it away -- even with -Force.
$preexisted = Test-Path -LiteralPath $abs
if ($preexisted -and -not $Force) { Fail "$file exists -- pass -Force to overwrite it" }

$parent = Split-Path -Parent $abs
try {
    [void][IO.Directory]::CreateDirectory($parent)
} catch {
    Fail "cannot create $parent"
}

# --- the clipboard ---------------------------------------------------------

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Opening the clipboard fails with CLIPBRD_E_CANT_OPEN while another process
# holds it -- a clipboard manager, or the app that has just written to it. It
# clears within milliseconds, so retry briefly before giving up.
$cb = $null
for ($try = 0; $try -lt 10; $try++) {
    try { $cb = [Windows.Forms.Clipboard]::GetDataObject(); break }
    catch { Start-Sleep -Milliseconds 150 }
}
if ($null -eq $cb) { Fail 'the clipboard stayed locked by another process' }

$written = $false
try {
    # 1. The original PNG bytes, when there are any and PNG is what is wanted.
    if ($fmt -eq 'png' -and $cb.GetDataPresent('PNG')) {
        $s = $cb.GetData('PNG')
        if ($s -is [IO.Stream]) {
            $f = [IO.File]::Create($abs)
            try { $s.Position = 0; $s.CopyTo($f) } finally { $f.Dispose() }
            $written = $true
        }
    }

    # 2. A bitmap, encoded by .NET into whatever was asked for.
    if (-not $written -and $cb.ContainsImage()) {
        $img = [Windows.Forms.Clipboard]::GetImage()
        if ($null -eq $img) { Fail 'no image on the clipboard' 3 }
        switch ($fmt) {
            'png' { $img.Save($abs, [Drawing.Imaging.ImageFormat]::Png) }
            'gif' { $img.Save($abs, [Drawing.Imaging.ImageFormat]::Gif) }
            'bmp' { $img.Save($abs, [Drawing.Imaging.ImageFormat]::Bmp) }
            'tif' { $img.Save($abs, [Drawing.Imaging.ImageFormat]::Tiff) }
            'jpg' {
                # JPEG has no alpha; flatten onto white first or GDI+ paints the
                # transparent parts black.
                $flat = New-Object Drawing.Bitmap $img.Width, $img.Height, ([Drawing.Imaging.PixelFormat]::Format24bppRgb)
                $g = [Drawing.Graphics]::FromImage($flat)
                $g.Clear([Drawing.Color]::White)
                $g.DrawImage($img, 0, 0, $img.Width, $img.Height)
                $g.Dispose()
                $codec = [Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
                $p = New-Object Drawing.Imaging.EncoderParameters 1
                $p.Param[0] = New-Object Drawing.Imaging.EncoderParameter ([Drawing.Imaging.Encoder]::Quality, [long]92)
                $flat.Save($abs, $codec, $p)
            }
        }
        $written = $true
    }

    # 3. A copied file. Only a single one makes sense for a single target.
    if (-not $written -and $cb.ContainsFileDropList()) {
        $files = $cb.GetFileDropList()
        if ($files.Count -ne 1) { Fail "the clipboard holds $($files.Count) files, not one image" }
        $src = $files[0]
        if (-not (Test-Path -LiteralPath $src -PathType Leaf)) {
            Fail "the clipboard names a file that cannot be read: $src"
        }
        $srcExt = ([IO.Path]::GetExtension($src) -replace '^\.', '').ToLowerInvariant()
        $srcFmt = switch ($srcExt) { 'jpeg' { 'jpg' } 'tiff' { 'tif' } default { $srcExt } }
        if ($srcFmt -ne $fmt) {
            if (-not $autoNamed) {
                Fail "the clipboard holds a .$srcExt file, not an image -- copying it to .$ext would not convert it"
            }
            # Keep the source's format; only the name was ours to choose. The
            # .png name was never written to, but the new name may be somebody's.
            $file = $file -replace '\.png$', ".$srcExt"
            $abs = $abs -replace '\.png$', ".$srcExt"
            $preexisted = Test-Path -LiteralPath $abs
            if ($preexisted -and -not $Force) { Fail "$file exists -- pass -Force to overwrite it" }
        }
        # Bytes, not Copy-Item: the copy is a new file, not the source's
        # attributes (a read-only one would stay read-only).
        [IO.File]::WriteAllBytes($abs, [IO.File]::ReadAllBytes($src))
        $written = $true
    }

    if (-not $written) { Fail 'no image on the clipboard' 3 }
} catch {
    Fail "$($_.Exception.Message)"
} finally {
    # A partial file is worse than none -- but only one this run created.
    if (-not $written -and -not $preexisted -and (Test-Path -LiteralPath $abs)) {
        Remove-Item -LiteralPath $abs -Force -ErrorAction SilentlyContinue
    }
}

# The path the caller gave, not the resolved one, as the .sh prints it.
$file
exit 0
