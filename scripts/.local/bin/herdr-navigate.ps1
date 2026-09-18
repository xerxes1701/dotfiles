#!/usr/bin/env pwsh
# Focus the herdr pane in a direction, or let nvim move between its splits.
#
# The Windows twin of smart-splits.nvim's bundled herdr plugin, which is what
# herdr/ and .herdr-devcontainer/ bind layer 0 to. That plugin cannot serve
# this side twice over: its manifest says platforms = ["linux", "macos"], and
# each of its four actions runs `bash scripts/herdr-navigate.sh` with jq, where
# herdr on Windows runs a command through `cmd.exe /d /c`. So .herdr-windows/
# binds this file instead -- the fourth .ps1 twin, next to the resize script
# and the two cycle scripts.
#
# The decision per keypress is the plugin's own, kept in step with it and with
# herdr-resize-pane.ps1, so that navigating and resizing never disagree about
# which panes belong to the editor:
#
#   1. the focused pane's foreground process looks like vim: forward the key
#      into the pane and let the editor move its own split.
#   2. otherwise focus the neighbour in that direction.
#   3. no neighbour, or no answer: send the key back to the pane, so that the
#      shell keeps its default binding at the edge of the grid -- ctrl+l
#      clears, ctrl+h is backspace -- rather than losing it to a key that
#      moved nothing. The .sh spells this as two cases, "no_neighbor" and
#      "could not tell"; anything but a focus that changed ends up here.
#
# What Windows changes is what the other twins change: process names carry an
# .exe suffix, which is stripped before the vim regex sees it, and
# ConvertFrom-Json does what jq does there.
#
# Step 1 is kept although nothing on this side installs nvim: the three herdr
# configs describe one scheme, and the day an nvim.exe runs in a pane the key
# has to reach it. An nvim inside a WSL pane stays invisible to it either way
# -- herdr sees wsl.exe, and the linux process behind it is not its to see.
#
# Usage: herdr-navigate.ps1 <left|down|up|right>
param([Parameter(Position = 0)][string]$Direction = '')

switch ($Direction) {
    'left'  { $key = 'ctrl+h' }
    'down'  { $key = 'ctrl+j' }
    'up'    { $key = 'ctrl+k' }
    'right' { $key = 'ctrl+l' }
    default {
        [Console]::Error.WriteLine('herdr-navigate.ps1: usage: herdr-navigate.ps1 <left|down|up|right>')
        exit 2
    }
}

$herdr = if ($env:HERDR_BIN_PATH) { $env:HERDR_BIN_PATH } else { 'herdr' }
$pane = if ($env:HERDR_ACTIVE_PANE_ID) { $env:HERDR_ACTIVE_PANE_ID } else { $env:HERDR_PANE_ID }
if (-not $pane) { exit 0 }

# Runs a herdr query and parses its JSON envelope; $null on any failure, which
# every caller treats as "do nothing", as the .sh does.
function Invoke-HerdrJson {
    param([string[]]$HerdrArgs)
    try {
        $out = & $herdr @HerdrArgs 2>$null
        if ($LASTEXITCODE -ne 0) { return $null }
        return ($out -join "`n") | ConvertFrom-Json
    } catch { return $null }
}

# 1. Names are lowercased first, so the match is case-sensitive on purpose, as
# jq's test() is.
$vimRe = '^g?(view|l?n?vim?x?)(diff)?$'
$passRe = $env:SMART_SPLITS_HERDR_PASSTHROUGH_RE
$info = Invoke-HerdrJson @('pane', 'process-info', '--pane', $pane)
$names = @($info.result.process_info.foreground_processes |
    ForEach-Object { $_.name } | Where-Object { $_ } |
    ForEach-Object { $_.ToLowerInvariant() -replace '\.exe$', '' })
foreach ($name in $names) {
    $owns = $name -cmatch $vimRe
    if (-not $owns -and $passRe) {
        try { $owns = $name -cmatch $passRe } catch { $owns = $false }
    }
    if ($owns) {
        & $herdr pane send-keys $pane $key
        exit $LASTEXITCODE
    }
}

# 2. A neighbour in that direction, and the focus moved.
$focus = Invoke-HerdrJson @('pane', 'focus', '--direction', $Direction, '--pane', $pane)
if ($focus -and $focus.result.focus.changed) { exit 0 }

# 3. Everything else: the key belongs to whatever is in the pane.
& $herdr pane send-keys $pane $key
exit $LASTEXITCODE
