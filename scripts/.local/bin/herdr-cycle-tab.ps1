#!/usr/bin/env pwsh
# Focus the next or previous tab in the active herdr workspace.
#
# The Windows twin of herdr-cycle-tab.sh, bound from .herdr-windows/ where the
# linux configs bind the shell script: on Windows herdr runs custom commands
# through `cmd.exe /d /c`, which cannot run a bash script. See the header of
# the .sh for why the binding exists; the logic here is the same, with
# ConvertFrom-Json in place of jq.
#
# Usage: herdr-cycle-tab.ps1 <next|prev>
param([Parameter(Position = 0)][string]$Step = '')

switch ($Step) {
    'next' { $delta = 1 }
    'prev' { $delta = -1 }
    default {
        [Console]::Error.WriteLine('herdr-cycle-tab.ps1: usage: herdr-cycle-tab.ps1 <next|prev>')
        exit 2
    }
}

$herdr = if ($env:HERDR_BIN_PATH) { $env:HERDR_BIN_PATH } else { 'herdr' }
$ws = $env:HERDR_ACTIVE_WORKSPACE_ID
$cur = $env:HERDR_ACTIVE_TAB_ID
if (-not $ws -or -not $cur) { exit 0 }

# `herdr tab list` returns the tabs of a workspace in tab-bar order.
try {
    $out = & $herdr tab list --workspace $ws 2>$null
    if ($LASTEXITCODE -ne 0) { exit 0 }
    $tabs = @(($out -join "`n" | ConvertFrom-Json).result.tabs |
        ForEach-Object { $_.tab_id } | Where-Object { $_ })
} catch { exit 0 }
if ($tabs.Count -le 1) { exit 0 }

$i = [Array]::IndexOf($tabs, $cur)
if ($i -lt 0) { exit 0 }

# Wraps at both ends, as tmux's next-window and nvim's tabnext do.
& $herdr tab focus $tabs[($i + $delta + $tabs.Count) % $tabs.Count]
exit $LASTEXITCODE
