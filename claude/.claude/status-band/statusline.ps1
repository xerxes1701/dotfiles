#!/usr/bin/env pwsh
# Status line for Claude Code: model and effort, directory, branch, then the
# context window and the 5-hour and weekly limits, then the output style and
# session name. Reads the status line JSON on stdin and prints ANSI-coloured
# lines.
#
# The Windows twin of statusline.mjs, for the Claude Code install on Windows,
# where there is no Node to run that one. The lines are the same; keep the two
# in step. It runs under Windows PowerShell 5.1 and PowerShell 7 alike, and
# stays ASCII -- every other character is spelled as a code point -- because
# 5.1 reads a script without a byte order mark in the ANSI code page.
#
# Usage, as the statusLine command in settings.json:
#   pwsh -NoProfile -File <checkout>\claude\.claude\status-band\statusline.ps1

$ErrorActionPreference = 'Stop'
$utf8 = New-Object Text.UTF8Encoding $false
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$inv = [Globalization.CultureInfo]::InvariantCulture

# Claude Code's directory rather than this file's, as in the .mjs.
$configDir = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else {
    Join-Path ([Environment]::GetFolderPath('UserProfile')) '.claude'
}
$stateDir = Join-Path $configDir 'status-band'

$esc = [char]27
function Rgb([int]$R, [int]$G, [int]$B, [string]$Text) { "$esc[38;2;$R;$G;${B}m$Text$esc[39m" }
function Bold([string]$Text) { "$esc[1m$Text$esc[22m" }
function Dim([string]$Text) { "$esc[2m$Text$esc[22m" }

function Claude([string]$Text) { Rgb 215 119 87 $Text }
function Label([string]$Text) { Rgb 107 107 107 $Text }
function Limit([string]$Text) { Rgb 97 175 239 $Text }
function Success([string]$Text) { Rgb 78 186 101 $Text }
function Warning([string]$Text) { Rgb 255 193 7 $Text }
function Error([string]$Text) { Rgb 255 107 128 $Text }

$dash = [string][char]0x2013
$sep = Dim '|'
$blankLines = 2

# Fills up with the level: low is almost empty, max is full.
$effortIcons = @{
    low    = [string][char]0x25D4
    medium = [string][char]0x25D1
    high   = [string][char]0x25D5
    xhigh  = [string][char]0x25C9
    max    = [string][char]0x25CF
}

# A property of a parsed JSON object, or $null: its name may hold brackets
# (claude-opus-5-5[1m]), and a missing one must not throw.
function Prop($Object, [string]$Name) {
    if ($null -eq $Object -or $Object -isnot [PSCustomObject]) { return $null }
    $p = $Object.PSObject.Properties[$Name]
    if ($p) { $p.Value } else { $null }
}

# JavaScript's Math.round, half up; [Math]::Round rounds half to even.
function Round-Half([double]$Value) { [Math]::Floor($Value + 0.5) }

function Num($Value) {
    if ($null -eq $Value -or $Value -is [bool] -or $Value -is [string]) { return $null }
    if ($Value -isnot [ValueType]) { return $null }
    $d = [double]$Value
    if ([double]::IsNaN($d) -or [double]::IsInfinity($d)) { $null } else { $d }
}

function Capitalize([string]$Word) {
    $Word.Substring(0, 1).ToUpperInvariant() + $Word.Substring(1).ToLowerInvariant()
}

function Pretty-Model([string]$Id, [string]$DisplayName) {
    $isLongContext = $Id -match '\[1m\]'
    $bare = ($Id -replace '\[.*?\]', '').Trim()
    $name = if ($bare -match '(?i)(opus|sonnet|haiku|fable)-(\d+)(?:-(\d{1,2}))?(?:-\d{8})?$') {
        $minor = if ($Matches[3]) { ".$($Matches[3])" } else { '' }
        "$(Capitalize $Matches[1]) $($Matches[2])$minor"
    } elseif ($DisplayName) { $DisplayName } elseif ($bare) { $bare } else { 'unknown' }
    if ($isLongContext -and $name -notmatch '(?i)1m') { "$name (1M)" } else { $name }
}

function Configured-Effort([string]$ModelId) {
    try {
        $settings = Get-Content -LiteralPath (Join-Path $configDir 'settings.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        $bare = ($ModelId -replace '\[.*?\]', '').Trim()
        $models = Prop $settings 'modelSettings'
        foreach ($level in (Prop (Prop $models $ModelId) 'effortLevel'), (Prop (Prop $models $bare) 'effortLevel'), (Prop $settings 'effortLevel')) {
            if ($null -ne $level) { return $level }
        }
    } catch {}
    $null
}

# git with the .mjs's two-second limit, so a slow share cannot hold the line.
function Git-Line([string]$Cwd, [string[]]$Arguments) {
    $info = New-Object Diagnostics.ProcessStartInfo 'git'
    $info.Arguments = (@('-C', "`"$Cwd`"") + $Arguments) -join ' '
    $info.UseShellExecute = $false
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.CreateNoWindow = $true
    $git = [Diagnostics.Process]::Start($info)
    $out = $git.StandardOutput.ReadToEndAsync()
    [void]$git.StandardError.ReadToEndAsync()
    if (-not $git.WaitForExit(2000)) { try { $git.Kill() } catch {}; throw 'git timed out' }
    if ($git.ExitCode -ne 0) { throw "git exited $($git.ExitCode)" }
    $out.Result.Trim()
}

function Branch-Of([string]$Cwd) {
    try {
        $branch = Git-Line $Cwd @('branch', '--show-current')
        if ($branch) { $branch } else { '@' + (Git-Line $Cwd @('rev-parse', '--short', 'HEAD')) }
    } catch { $null }
}

function Compact-Tokens([double]$N) {
    if ($N -ge 1000000) { return ([Math]::Round($N / 1000000, 1, [MidpointRounding]::AwayFromZero)).ToString($inv) + 'M' }
    if ($N -ge 1000) { return "$(Round-Half ($N / 1000))k" }
    "$N"
}

function Bar([double]$Percent, [int]$Width = 10) {
    $filled = [int][Math]::Min($Width, [Math]::Max(0, (Round-Half ($Percent / 100 * $Width))))
    ([string][char]0x2588) * $filled + ([string][char]0x2591) * ($Width - $filled)
}

function Used-Color([double]$Percent, [string]$Text) {
    if ($Percent -ge 80) { Error $Text } elseif ($Percent -ge 50) { Warning $Text } else { Success $Text }
}

$now = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()

function To-Ms($ResetsAt) {
    if ($null -eq $ResetsAt) { return $null }
    # PowerShell 7's ConvertFrom-Json turns an ISO date into a DateTime itself.
    if ($ResetsAt -is [DateTime]) { return ([DateTimeOffset]$ResetsAt.ToUniversalTime()).ToUnixTimeMilliseconds() }
    $n = Num $ResetsAt
    if ($null -ne $n) { return $(if ($n -lt 1e12) { $n * 1000 } else { $n }) }
    try {
        [DateTimeOffset]::Parse([string]$ResetsAt, $inv).ToUnixTimeMilliseconds()
    } catch { $null }
}

function Time-Until([double]$At) {
    $minutes = [Math]::Max(0, [Math]::Ceiling(($At - $now) / 60000))
    $days = [Math]::Floor($minutes / 1440)
    $hours = [Math]::Floor(($minutes % 1440) / 60)
    $mins = $minutes % 60
    if ($days -gt 0) { return "${days}d ${hours}h" }
    if ($hours -gt 0) { return "${hours}h $(([int]$mins).ToString('00'))m" }
    "${mins}m"
}

# Claude Code leaves a window out until it has usage (after a reset, and in a
# new session before its first response), so the last reading is kept here,
# in the .mjs's format.
$limitsCache = Join-Path $stateDir 'limits.json'
$spans = @{ five_hour = 5 * 3600000; seven_day = 7 * 86400000 }

function Read-Cache {
    $cache = @{}
    try {
        $parsed = Get-Content -LiteralPath $limitsCache -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($kind in 'five_hour', 'seven_day') {
            $entry = Prop $parsed $kind
            $used = Num (Prop $entry 'used')
            $at = Num (Prop $entry 'resetsAt')
            if ($null -ne $used -and $null -ne $at) { $cache[$kind] = @{ used = $used; resetsAt = $at } }
        }
    } catch {}
    $cache
}

# What a window stands at now: the live reading, else the last one while its
# window runs, else an unused window (a weekly one resets on the same weekly
# schedule; a 5-hour one starts with the next message).
function Resolve-Window([string]$Kind, $Live, [hashtable]$Cache) {
    $span = $spans[$Kind]
    $resetsAt = To-Ms (Prop $Live 'resets_at')
    # A reading whose window has ended says nothing about the one running now.
    $used = if ($null -ne $resetsAt -and $resetsAt -le $now) { $null } else { Num (Prop $Live 'used_percentage') }
    if ($null -ne $used -and $null -ne $resetsAt) {
        $Cache[$Kind] = @{ used = $used; resetsAt = $resetsAt }
        return @{ used = $used; resetsAt = $resetsAt }
    }
    $cached = $Cache[$Kind]
    if ($cached -and $cached.resetsAt -gt $now) {
        return @{ used = $(if ($null -ne $used) { $used } else { $cached.used }); resetsAt = $cached.resetsAt }
    }
    $known = @(@($cached.resetsAt, $resetsAt) | Where-Object { $null -ne $_ })
    if ($Kind -eq 'seven_day' -and $known.Count -gt 0) {
        $lastReset = ($known | Measure-Object -Maximum).Maximum
        $periods = [Math]::Max(0, [Math]::Floor(($now - $lastReset) / $span) + 1)
        return @{ used = $(if ($null -ne $used) { $used } else { 0 }); resetsAt = $lastReset + $periods * $span }
    }
    @{ used = $(if ($null -ne $used) { $used } else { 0 }); resetsAt = $now + $span }
}

function Limit-Part([string]$Name, [hashtable]$Window) {
    $left = [Math]::Max(0, (Round-Half (100 - $Window.used)))
    "$(Label $Name) $(Limit "$(Bar $left) $(Bold "$left%")") $(Dim "($(Time-Until $Window.resetsAt))")"
}

function Context-Part($Window) {
    $percent = Num (Prop $Window 'used_percentage')
    $size = Num (Prop $Window 'context_window_size')
    if ($null -eq $percent) {
        return "$(Label 'Context') $(Dim $(if ($null -eq $size) { $dash } else { "$dash of $(Compact-Tokens $size)" }))"
    }
    $rounded = Round-Half $percent
    $tokens = Num (Prop $Window 'total_input_tokens')
    $counts = if ($null -ne $tokens -and $null -ne $size) { ' ' + (Dim "$(Compact-Tokens $tokens)/$(Compact-Tokens $size)") } else { '' }
    "$(Label 'Context') $(Used-Color $rounded "$(Bar $rounded) $rounded%")$counts"
}

function Render($Data) {
    $model = Prop $Data 'model'
    $modelId = [string](Prop $model 'id')
    $level = Prop (Prop $Data 'effort') 'level'
    if ($null -eq $level) { $level = Configured-Effort $modelId }
    if ($null -eq $level) { $level = 'default' }
    $icon = $effortIcons[([string]$level).ToLowerInvariant()]
    if (-not $icon) { $icon = [string][char]0x25CB }
    $cwd = Prop (Prop $Data 'workspace') 'current_dir'
    if (-not $cwd) { $cwd = Prop $Data 'cwd' }
    if (-not $cwd) { $cwd = (Get-Location).ProviderPath }
    $branch = Branch-Of $cwd
    $columns = 0
    [void][int]::TryParse($env:COLUMNS, [ref]$columns)
    $cache = Read-Cache
    $limits = Prop $Data 'rate_limits'
    $fiveHour = Resolve-Window 'five_hour' (Prop $limits 'five_hour') $cache
    $weekly = Resolve-Window 'seven_day' (Prop $limits 'seven_day') $cache
    try {
        [void][IO.Directory]::CreateDirectory($stateDir)
        [IO.File]::WriteAllText($limitsCache, ($cache | ConvertTo-Json -Compress), $utf8)
    } catch {}

    $leaf = [IO.Path]::GetFileName($cwd.TrimEnd('\', '/'))
    $first = @(
        (Bold (Claude "[$(Pretty-Model $modelId ([string](Prop $model 'display_name'))) $icon $level]")),
        "$(Label 'Dir') $(if ($leaf) { $leaf } else { $cwd })",
        $(if ($null -eq $branch) { Dim '--' } else { Success $branch })
    ) -join " $sep "
    $second = @(
        (Context-Part (Prop $Data 'context_window')),
        (Limit-Part '5h' $fiveHour),
        (Limit-Part 'Weekly' $weekly)
    ) -join " $sep "
    # Claude Code sends session_name only once the session has one (/rename).
    $style = Prop (Prop $Data 'output_style') 'name'
    $session = Prop $Data 'session_name'
    $third = @(
        "$(Label 'Style') $(if ($null -ne $style) { $style } else { Dim $dash })",
        "$(Label 'Session') $(if ($null -ne $session) { $session } else { Dim $dash })"
    ) -join " $sep "
    $rule = Dim (([string][char]0x2500) * $(if ($columns -gt 0) { $columns } else { 80 }))

    # A line of one no-break space survives where an empty line would be dropped.
    (@($first, $second, $third) + @([string][char]0x00A0) * $blankLines + @($rule)) -join "`n"
}

$data = $null
try { $data = [Console]::In.ReadToEnd() | ConvertFrom-Json } catch {}
[Console]::Out.Write((Render $data))
