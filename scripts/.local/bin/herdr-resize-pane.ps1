#!/usr/bin/env pwsh
# Resize the boundary of the focused herdr pane, or let nvim resize its split.
#
# The Windows twin of herdr-resize-pane.sh, bound from .herdr-windows/ where
# the linux configs bind the shell script: on Windows herdr runs custom
# commands through `cmd.exe /d /c`, which cannot run a bash script. The header
# of the .sh explains the decision this makes and why (nvim in the focused
# pane forwards the key, anything else resizes the herdr pane; `--mux-only` is
# nvim's own call, which owns the cells-to-fraction conversion). Only what
# Windows changes is noted here:
#
#   - process names carry an .exe suffix (nvim.exe), which the vim regex the
#     navigation plugin uses does not expect, so it is stripped before matching
#   - jq is not needed: ConvertFrom-Json does the parsing
#   - the fraction is formatted with the invariant culture, or a German locale
#     would hand herdr "0,015"
#
# Usage: herdr-resize-pane.ps1 <left|down|up|right> [--mux-only]
param(
    [Parameter(Position = 0)][string]$Direction = '',
    [Parameter(Position = 1)][string]$Mode = ''
)

switch ($Direction) {
    'left'  { $key = 'ctrl+left';  $axis = 'width' }
    'right' { $key = 'ctrl+right'; $axis = 'width' }
    'up'    { $key = 'ctrl+up';    $axis = 'height' }
    'down'  { $key = 'ctrl+down';  $axis = 'height' }
    default {
        [Console]::Error.WriteLine("herdr-resize-pane.ps1: usage: herdr-resize-pane.ps1 <left|down|up|right> [--mux-only]")
        exit 2
    }
}

$herdr = if ($env:HERDR_BIN_PATH) { $env:HERDR_BIN_PATH } else { 'herdr' }
$pane = if ($env:HERDR_ACTIVE_PANE_ID) { $env:HERDR_ACTIVE_PANE_ID } else { $env:HERDR_PANE_ID }
if (-not $pane) { exit 0 }

# 3 cells, the same step smart-splits.nvim takes in nvim (default_amount) and
# in tmux (@smart-splits_resize_step_size).
$cells = 3

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

if ($Mode -ne '--mux-only') {
    # Kept character for character in step with smart-splits.nvim's own
    # herdr-navigate.sh, so navigation and resizing never disagree about which
    # panes belong to the editor. Names are lowercased first, so the match is
    # case-sensitive on purpose, as jq's test() is.
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
}

# The fraction that moves the boundary by `cells`. The denominator is the pane
# area of the tab, which is what the split's ratio is a fraction of -- not the
# pane's own size, and not the terminal's.
$edges = Invoke-HerdrJson @('pane', 'edges', '--pane', $pane)
$area = $edges.result.edges.layout.area.$axis
if (-not $area -or [double]$area -le 0) { exit 0 }
$amount = ([double]$cells / [double]$area).ToString([Globalization.CultureInfo]::InvariantCulture)

& $herdr pane resize --direction $Direction --amount $amount --pane $pane
exit $LASTEXITCODE
