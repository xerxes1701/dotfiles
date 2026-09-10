#Requires -Version 5.1
<#
.SYNOPSIS
    Filesystem access performance probe, run from Windows.

.DESCRIPTION
    Measures the two Windows-side halves of the WSL/Windows filesystem matrix:

        ntfs   Windows -> NTFS   (native local disk, e.g. %TEMP%)
        ext4   Windows -> ext4   (WSL VM disk over \\wsl.localhost\<distro>)

    The WSL-side halves (WSL -> ext4 native and WSL -> NTFS through drvfs)
    are measured by the companion script fs-perf.sh.

    Both scripts build the *same* synthetic code repository - identical
    directory layout, file names, file sizes and byte content - and run the
    same phases, so all four combinations can be compared.

    Uses nothing but Windows PowerShell 5.1 and the .NET BCL.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\fs-perf.ps1

.EXAMPLE
    pwsh -File .\fs-perf.ps1 -Count 5000 -Targets ntfs -Csv results.csv

.NOTES
    Execution policy: a file living under \\wsl.localhost counts as remote, so
    under RemoteSigned (a common machine policy, which -ExecutionPolicy cannot
    override) running it in place is blocked. Either copy it to a local drive
    first, or run it without touching the file-based policy:

        powershell -NoProfile -Command "& ([ScriptBlock]::Create((Get-Content -Raw \
            \\wsl.localhost\<distro>\home\<user>\dotfiles\scripts\.local\bin\fs-perf.ps1) \
            -replace '(?m)^#Requires.*$','')) -Count 2000"
#>
[CmdletBinding()]
param(
    [int] $Count = 2000,
    [ValidateSet('ntfs', 'ext4')]
    [string[]] $Targets = @('ntfs', 'ext4'),
    [string] $NtfsDir,
    [string] $Ext4Dir,
    [switch] $Keep,
    [string] $Csv
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

# Numbers must read the same on every machine: no locale decimal commas.
[System.Threading.Thread]::CurrentThread.CurrentCulture =
    [System.Globalization.CultureInfo]::InvariantCulture

if ($Count -lt 10) { throw '-Count must be >= 10' }

$Phases   = @('mkdir', 'write', 'sync', 'stat', 'read', 'grep', 'modify', 'rename', 'delete')
# -Keep exists to leave the corpus behind for inspection, so the delete phase
# would defeat it; drop that phase instead of the request.
if ($Keep) { $Phases = @($Phases | Where-Object { $_ -ne 'delete' }) }
$DirCount = [int][math]::Ceiling($Count / 10)
$ModCount = [int][math]::Ceiling($Count / 10)
$Enc      = New-Object System.Text.UTF8Encoding($false)   # no BOM
$Token    = 'TODO(perf)'
$Results  = @{}
$Bytes    = @{}

# ------------------------------------------------------------- templates ----
# Byte-for-byte the same corpus fs-perf.sh generates: one code-like "unit"
# per file kind, repeated 1/2/4/6/10 times so sizes spread like a real repo.

$SlashTodo = "`n// TODO(perf) revisit hot path before release"
$HashTodo  = "`n# TODO(perf) revisit hot path before release"
$Nl2       = "`n`n"

$Units = @(
@'
export interface RequestContext {
  traceId: string;
  userId: string | null;
  startedAt: number;
}

export async function handleRequest(ctx: RequestContext, payload: Record<string, unknown>) {
  const started = Date.now();
  try {
    const result = await dispatch(ctx.traceId, payload);
    return { ok: true, result, durationMs: Date.now() - started };
  } catch (err) {
    logger.error("dispatch failed", { traceId: ctx.traceId, err });
    return { ok: false, error: String(err) };
  }
}

'@,
@'
import { useEffect, useState } from "react";

export function StatusBadge({ jobId }: { jobId: string }) {
  const [state, setState] = useState<"idle" | "running" | "done">("idle");
  useEffect(() => {
    const timer = setInterval(() => void poll(jobId).then(setState), 2000);
    return () => clearInterval(timer);
  }, [jobId]);
  return <span className={"badge badge--" + state}>{state}</span>;
}

'@,
@'
const { createHash } = require("node:crypto");

function cacheKey(parts) {
  const h = createHash("sha256");
  for (const p of parts) h.update(String(p)).update("|");
  return h.digest("hex").slice(0, 32);
}

async function retry(fn, attempts = 3, delayMs = 50) {
  let lastErr;
  for (let i = 0; i < attempts; i += 1) {
    try {
      return await fn();
    } catch (e) {
      lastErr = e;
      await sleep(delayMs * (i + 1));
    }
  }
  throw lastErr;
}

module.exports = { cacheKey, retry };

'@,
@'
from dataclasses import dataclass


@dataclass(frozen=True)
class Record:
    key: str
    value: bytes
    version: int = 0


def merge(left, right):
    """Last writer wins, per key, by version."""
    out = dict(left)
    for key, rec in right.items():
        cur = out.get(key)
        if cur is None or cur.version < rec.version:
            out[key] = rec
    return out

'@,
@'
package store

import (
    "context"
    "errors"
    "time"
)

var ErrNotFound = errors.New("store: not found")

func (s *Store) Get(ctx context.Context, key string) ([]byte, error) {
    ctx, cancel := context.WithTimeout(ctx, 2*time.Second)
    defer cancel()
    v, ok := s.cache.Load(key)
    if !ok {
        return nil, ErrNotFound
    }
    return v.([]byte), nil
}

'@,
@'
  {"name": "dep-a", "version": "1.4.2", "resolved": "https://registry.example.com/dep-a/-/dep-a-1.4.2.tgz", "integrity": "sha512-AAAABBBBCCCCDDDDEEEEFFFF0000111122223333444455556666777788889999", "dev": false},
  {"name": "dep-b", "version": "0.9.17", "resolved": "https://registry.example.com/dep-b/-/dep-b-0.9.17.tgz", "integrity": "sha512-9999888877776666555544443333222211110000FFFFEEEEDDDDCCCCBBBBAAAA", "dev": true},
'@,
@'
## Overview

This module owns request fan-out and retry accounting. It deliberately
avoids framework imports so it can be exercised from plain unit tests.

- `handleRequest` normalises the incoming payload
- `retry` applies linear backoff and re-raises the last error
- every failure is logged with the trace id, never swallowed

    make test PKG=./src/...

'@,
@'
.panel {
  display: grid;
  grid-template-columns: minmax(12rem, 18rem) 1fr;
  gap: var(--space-3, 12px);
  border: 1px solid var(--border-muted, #d0d7de);
  border-radius: 6px;
}

.panel > header {
  font: 600 13px/1.4 ui-sans-serif, system-ui, sans-serif;
  color: var(--fg-default, #1f2328);
}

'@,
@'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-gateway
spec:
  replicas: 3
  template:
    spec:
      containers:
        - name: api
          image: registry.example.com/api:1.4.2
          resources:
            requests:
              cpu: 250m
              memory: 256Mi

'@,
@'
set -eu

log() {
  printf "%s %s\n" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >&2
}

main() {
  [ $# -ge 1 ] || { log "usage: build.sh TARGET"; return 2; }
  target=$1
  log "building ${target}"
  make -C "src/${target}" all
}

'@
)

# ext, base name, header prefix, todo snippet, header/body separator, suffix
$Kinds = @(
    @{ Ext = 'ts';   Name = 'service';  P = '// module ';    T = $SlashTodo; M = $Nl2;      Q = '' },
    @{ Ext = 'tsx';  Name = 'Panel';    P = '// module ';    T = $SlashTodo; M = $Nl2;      Q = '' },
    @{ Ext = 'js';   Name = 'util';     P = '// module ';    T = $SlashTodo; M = $Nl2;      Q = '' },
    @{ Ext = 'py';   Name = 'models';   P = '# module ';     T = $HashTodo;  M = $Nl2;      Q = '' },
    @{ Ext = 'go';   Name = 'store';    P = '// module ';    T = $SlashTodo; M = $Nl2;      Q = '' },
    @{ Ext = 'json'; Name = 'lockfile'; P = '{"id": ';
       T = ', "todo": "TODO(perf) revisit hot path before release"';
       M = ", `"entries`": [`n";
       Q = "  {`"name`": `"dep-omega`", `"version`": `"0.0.1`", `"dev`": true}`n]}`n" },
    @{ Ext = 'md';   Name = 'notes';    P = '<!-- module ';
       T = ' TODO(perf) revisit hot path before release'; M = " -->`n`n"; Q = '' },
    @{ Ext = 'css';  Name = 'styles';   P = '/* module ';
       T = ' TODO(perf) revisit hot path before release'; M = " */`n`n"; Q = '' },
    @{ Ext = 'yaml'; Name = 'deploy';   P = '# module ';     T = $HashTodo;  M = $Nl2;      Q = '' },
    @{ Ext = 'sh';   Name = 'build';    P = '# module ';     T = $HashTodo;  M = $Nl2;      Q = '' }
)

# Two adjustments so the corpus is byte-identical to the one fs-perf.sh writes:
# force LF (here-strings pick up whatever line endings this file has on disk),
# and restore the trailing newline PowerShell strips before the '@ terminator.
for ($k = 0; $k -lt $Units.Count; $k++) {
    $Units[$k] = $Units[$k].Replace("`r`n", "`n") + "`n"
}

# Precompute the repeated bodies once, so the write phase measures the
# filesystem and not string concatenation.
$Repeats = @(1, 2, 4, 6, 10)
$Bodies = New-Object 'System.String[,]' 10, 5
for ($s = 0; $s -lt $Repeats.Count; $s++) {
    for ($k = 0; $k -lt 10; $k++) {
        $sb = New-Object System.Text.StringBuilder
        for ($j = 0; $j -lt $Repeats[$s]; $j++) { [void]$sb.Append($Units[$k]) }
        $Bodies[$k, $s] = $sb.ToString()
    }
}

# ---------------------------------------------------------------- helpers ----

function Get-LeafDir {
    param([string] $Root, [int] $Index)
    $pkg  = [int][math]::Floor($Index / 100)
    $part = [int][math]::Floor(($Index % 100) / 10)
    return ('{0}\src\pkg{1:00}\part{2}' -f $Root, $pkg, $part)
}

function Get-FilePath {
    param([string] $Root, [int] $Index)
    $kind = $Kinds[$Index % 10]
    return ('{0}\{1}_{2}.{3}' -f (Get-LeafDir $Root $Index), $kind.Name, $Index, $kind.Ext)
}

function Get-OpsFor {
    param([string] $Phase)
    switch ($Phase) {
        'mkdir'  { $DirCount }
        'modify' { $ModCount }
        'rename' { $ModCount }
        'sync'   { 0 }
        'delete' { 0 }
        default  { $Count }
    }
}

function Format-Ms {
    param([int] $Ms)
    if ($Ms -lt 0) { return 'n/a' }
    return ('{0}.{1:000}' -f [int][math]::Floor($Ms / 1000), ($Ms % 1000))
}

function Format-Ratio {
    param([int] $Base, [int] $Other)
    if ($Base -lt 0 -or $Other -lt 0) { return '-' }
    if ($Base -lt 1) { $Base = 1 }
    return ('{0:0.00}x' -f ($Other / $Base))
}

function Write-PhaseResult {
    param(
        [string] $Target,
        [string] $Phase,
        [int] $Ms,
        [long] $TotalBytes
    )
    $Results["$Target/$Phase"] = $Ms
    if ($Ms -lt 0) {
        Write-Host ('  {0,-7} {1,10}' -f $Phase, 'n/a')
        return
    }
    $ops = Get-OpsFor $Phase
    $div = [math]::Max($Ms, 1)
    $rate = if ($ops -gt 0) { '{0}/s' -f [int]($ops * 1000 / $div) } else { '-' }
    $extra = ''
    if (($Phase -eq 'write' -or $Phase -eq 'read') -and $TotalBytes -gt 0) {
        $extra = '{0:0.00} MiB/s' -f ($TotalBytes * 1000 / $div / 1MB)
    }
    Write-Host ('  {0,-7} {1,9}s  {2,-10} {3}' -f $Phase, (Format-Ms $Ms), $rate, $extra)
}

# ----------------------------------------------------------------- phases ----

function Invoke-PhaseMkdir {
    param([string] $Root)
    for ($i = 0; $i -lt $Count; $i += 10) {
        [void][System.IO.Directory]::CreateDirectory((Get-LeafDir $Root $i))
    }
}

function Invoke-PhaseWrite {
    param([string] $Root)
    $total = [long]0
    for ($i = 0; $i -lt $Count; $i++) {
        $k = $i % 10
        $s = $i % 5
        $kind = $Kinds[$k]
        $todo = if (($i % 7) -eq 0) { $kind.T } else { '' }
        $content = $kind.P + $i + $todo + $kind.M + $Bodies[$k, $s] + $kind.Q
        [System.IO.File]::WriteAllText((Get-FilePath $Root $i), $content, $Enc)
        $total += $Enc.GetByteCount($content)
    }
    return $total
}

function Invoke-PhaseStat {
    param([string] $Root)
    $n = 0
    foreach ($f in [System.IO.Directory]::EnumerateFiles(
            $Root, '*', [System.IO.SearchOption]::AllDirectories)) {
        $fi = New-Object System.IO.FileInfo($f)
        if ($fi.Length -gt 0) { $n++ }
    }
    return $n
}

function Invoke-PhaseRead {
    param([string] $Root)
    $buf = New-Object byte[] 65536
    $sum = [long]0
    foreach ($f in [System.IO.Directory]::EnumerateFiles(
            $Root, '*', [System.IO.SearchOption]::AllDirectories)) {
        $fs = [System.IO.File]::OpenRead($f)
        try {
            while (($r = $fs.Read($buf, 0, $buf.Length)) -gt 0) { $sum += $r }
        } finally { $fs.Dispose() }
    }
    return $sum
}

function Invoke-PhaseGrep {
    param([string] $Root)
    $hits = 0
    foreach ($f in [System.IO.Directory]::EnumerateFiles(
            $Root, '*', [System.IO.SearchOption]::AllDirectories)) {
        if ([System.IO.File]::ReadAllText($f).IndexOf($Token) -ge 0) { $hits++ }
    }
    return $hits
}

function Invoke-PhaseModify {
    param([string] $Root)
    for ($i = 0; $i -lt $Count; $i += 10) {
        [System.IO.File]::AppendAllText((Get-FilePath $Root $i), "// touched by fs-perf`n", $Enc)
    }
}

function Invoke-PhaseRename {
    param([string] $Root)
    for ($i = 0; $i -lt $Count; $i += 10) {
        $p = Get-FilePath $Root $i
        [System.IO.File]::Move($p, $p + '.bak')
    }
}

function Invoke-PhaseDelete {
    param([string] $Root)
    [System.IO.Directory]::Delete($Root, $true)
}

function Invoke-Target {
    param([string] $Target, [string] $Root)

    Write-Host ''
    Write-Host ("== $Target ==")
    Write-Host ("   path:   $Root")
    try {
        $drive = [System.IO.Path]::GetPathRoot($Root)
        if ($Root.StartsWith('\\')) {
            Write-Host '   kind:   UNC / SMB redirector into the WSL VM (9p plan9 server)'
        } else {
            $di = New-Object System.IO.DriveInfo($drive)
            Write-Host ('   kind:   {0} {1}, {2:0.0} GiB free' -f `
                $di.DriveType, $di.DriveFormat, ($di.AvailableFreeSpace / 1GB))
        }
    } catch { }

    $totalBytes = [long]0
    foreach ($phase in $Phases) {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $ms = -1
        try {
            switch ($phase) {
                'mkdir'  { Invoke-PhaseMkdir  $Root | Out-Null }
                'write'  { $totalBytes = Invoke-PhaseWrite $Root }
                'sync'   { }   # Windows has no cheap global fsync; reported as n/a
                'stat'   { Invoke-PhaseStat   $Root | Out-Null }
                'read'   { Invoke-PhaseRead   $Root | Out-Null }
                'grep'   { Invoke-PhaseGrep   $Root | Out-Null }
                'modify' { Invoke-PhaseModify $Root | Out-Null }
                'rename' { Invoke-PhaseRename $Root | Out-Null }
                'delete' { Invoke-PhaseDelete $Root | Out-Null }
            }
            $sw.Stop()
            if ($phase -ne 'sync') { $ms = [int]$sw.Elapsed.TotalMilliseconds }
        } catch {
            $sw.Stop()
            Write-Host ('  {0,-7} {1,10}  FAILED: {2}' -f $phase, '-', $_.Exception.Message)
            $Results["$Target/$phase"] = -2
            continue
        }
        Write-PhaseResult -Target $Target -Phase $phase -Ms $ms -TotalBytes $totalBytes
    }
    $Bytes[$Target] = $totalBytes
}

# ------------------------------------------------------------ target dirs ----

function Test-WritableDir {
    param([string] $Dir)
    try {
        $probe = Join-Path $Dir ('.fs-perf-probe.' + $PID)
        [void][System.IO.Directory]::CreateDirectory($probe)
        [System.IO.Directory]::Delete($probe)
        return $true
    } catch { return $false }
}

function Resolve-Ext4Base {
    if ($Ext4Dir) { return $Ext4Dir }
    $wsl = Get-Command wsl.exe -ErrorAction SilentlyContinue
    if (-not $wsl) { return $null }
    $prevEnc = [Console]::OutputEncoding
    try {
        [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
        # No -d: this hits the default distro and reports its own name.
        $distro  = (& wsl.exe -e sh -c 'printf %s "$WSL_DISTRO_NAME"' 2>$null) -join ''
        $wslHome = (& wsl.exe -e sh -c 'printf %s "$HOME"' 2>$null) -join ''
    } catch {
        return $null
    } finally {
        [Console]::OutputEncoding = $prevEnc
    }
    $distro  = ($distro  -replace "`0", '').Trim()
    $wslHome = ($wslHome -replace "`0", '').Trim()
    if (-not $distro -or -not $wslHome) { return $null }
    foreach ($prefix in @('\\wsl.localhost\', '\\wsl$\')) {
        $unc = $prefix + $distro + ($wslHome -replace '/', '\')
        if (Test-Path -LiteralPath $unc) {
            return (Join-Path $unc '.cache\fs-perf')
        }
    }
    return $null
}

function Resolve-NtfsBase {
    if ($NtfsDir) { return $NtfsDir }
    $t = $env:TEMP
    if (-not $t) { $t = $env:TMP }
    if (-not $t) { return $null }
    return (Join-Path $t 'fs-perf')
}

# ------------------------------------------------------------------- main ----

Write-Host ('fs-perf: {0} files in {1} dirs' -f $Count, $DirCount)
Write-Host ('host:    {0}' -f [System.Environment]::OSVersion.VersionString)
Write-Host ('shell:   PowerShell {0}' -f $PSVersionTable.PSVersion)
try {
    $mp = Get-MpComputerStatus -ErrorAction SilentlyContinue
    if ($mp) {
        Write-Host ('defender realtime scanning: {0} (skews NTFS numbers)' -f `
            $mp.RealTimeProtectionEnabled)
    }
} catch { }

$roots = [ordered]@{}
foreach ($t in $Targets) {
    $base = if ($t -eq 'ntfs') { Resolve-NtfsBase } else { Resolve-Ext4Base }
    if (-not $base) {
        $hint = if ($t -eq 'ntfs') { '-NtfsDir <path>' } else { '-Ext4Dir <unc-path>' }
        Write-Warning ('skipping {0}: no usable base dir, pass {1}' -f $t, $hint)
        continue
    }
    try {
        [void][System.IO.Directory]::CreateDirectory($base)
    } catch {
        Write-Warning ('skipping {0}: cannot create {1}: {2}' -f $t, $base, $_.Exception.Message)
        continue
    }
    if (-not (Test-WritableDir $base)) {
        Write-Warning ('skipping {0}: {1} is not writable' -f $t, $base)
        continue
    }
    $roots[$t] = Join-Path $base ('fsperf-' + $PID)
}

if ($roots.Count -eq 0) { throw 'no usable targets' }

try {
    foreach ($t in $roots.Keys) { Invoke-Target -Target $t -Root $roots[$t] }
} finally {
    if (-not $Keep) {
        foreach ($t in $roots.Keys) {
            if (Test-Path -LiteralPath $roots[$t]) {
                Remove-Item -LiteralPath $roots[$t] -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

# ------------------------------------------------------------------ table ----

$names  = @($roots.Keys)
$first  = $names[0]
$second = if ($names.Count -ge 2) { $names[1] } else { $null }

$header = '{0,-8}' -f 'phase'
foreach ($t in $names) { $header += '{0,12}' -f $t }
if ($second) { $header += '{0,12}' -f 'slowdown' }
Write-Host ''
Write-Host $header
$rule = '{0,-8}' -f '-------'
foreach ($t in $names) { $rule += '{0,12}' -f '-----------' }
if ($second) { $rule += '{0,12}' -f '-----------' }
Write-Host $rule

$totals = @{}
foreach ($t in $names) { $totals[$t] = 0 }

foreach ($phase in $Phases) {
    $line = '{0,-8}' -f $phase
    foreach ($t in $names) {
        $v = $Results["$t/$phase"]
        if ($v -eq -2) {
            $line += '{0,12}' -f 'fail'
        } elseif ($v -lt 0) {
            $line += '{0,12}' -f 'n/a'
        } else {
            $line += '{0,11}s' -f (Format-Ms $v)
            $totals[$t] += $v
        }
    }
    if ($second) {
        $line += '{0,12}' -f (Format-Ratio $Results["$first/$phase"] $Results["$second/$phase"])
    }
    Write-Host $line
}

$line = '{0,-8}' -f 'TOTAL'
foreach ($t in $names) { $line += '{0,11}s' -f (Format-Ms $totals[$t]) }
if ($second) { $line += '{0,12}' -f (Format-Ratio $totals[$first] $totals[$second]) }
Write-Host $line

Write-Host ''
Write-Host ('corpus: {0} files, {1} bytes ({2:0.0} MiB)' -f `
    $Count, $Bytes[$first], ($Bytes[$first] / 1MB))
Write-Host 'note:   the sync phase is n/a on Windows (no cheap global fsync), so'
Write-Host '        write numbers here stop at the OS cache, like fs-perf.sh before its sync.'

if ($Csv) {
    $rows = foreach ($t in $names) {
        foreach ($phase in $Phases) {
            '{0},{1},{2},{3}' -f $t, $phase, $Results["$t/$phase"], (Get-OpsFor $phase)
        }
    }
    @('target,phase,ms,ops') + $rows | Set-Content -LiteralPath $Csv -Encoding ASCII
    Write-Host ('csv:    {0}' -f $Csv)
}

if ($Keep) {
    Write-Host 'kept:'
    foreach ($t in $names) { Write-Host ('  {0}' -f $roots[$t]) }
}

Write-Host ''
Write-Host 'For the WSL-side halves of the matrix run fs-perf.sh from WSL.'
