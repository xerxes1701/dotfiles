#!/usr/bin/env pwsh
# Focus the next or previous herdr workspace.
#
# The Windows twin of herdr-cycle-workspace.sh, bound from .herdr-windows/
# where the linux configs bind the shell script: on Windows herdr runs custom
# commands through `cmd.exe /d /c`, which cannot run a bash script. See the
# header of the .sh for why the binding exists; the logic here is the same,
# with ConvertFrom-Json in place of jq.
#
# Usage: herdr-cycle-workspace.ps1 <next|prev>
param([Parameter(Position = 0)][string]$Step = '')

switch ($Step) {
    'next' { $delta = 1 }
    'prev' { $delta = -1 }
    default {
        [Console]::Error.WriteLine('herdr-cycle-workspace.ps1: usage: herdr-cycle-workspace.ps1 <next|prev>')
        exit 2
    }
}

$herdr = if ($env:HERDR_BIN_PATH) { $env:HERDR_BIN_PATH } else { 'herdr' }
$cur = $env:HERDR_ACTIVE_WORKSPACE_ID
if (-not $cur) { exit 0 }

# `herdr workspace list` returns the workspaces in sidebar order.
try {
    $out = & $herdr workspace list 2>$null
    if ($LASTEXITCODE -ne 0) { exit 0 }
    $spaces = @(($out -join "`n" | ConvertFrom-Json).result.workspaces |
        ForEach-Object { $_.workspace_id } | Where-Object { $_ })
} catch { exit 0 }
if ($spaces.Count -le 1) { exit 0 }

$i = [Array]::IndexOf($spaces, $cur)
if ($i -lt 0) { exit 0 }

# Wraps at both ends, as tmux's switch-client does.
& $herdr workspace focus $spaces[($i + $delta + $spaces.Count) % $spaces.Count]
exit $LASTEXITCODE
