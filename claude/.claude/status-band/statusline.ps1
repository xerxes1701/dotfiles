#!/usr/bin/env pwsh
# Status line for Claude Code, drawn as chevrons in muted colours: every line
# is one powerline strip, coloured bands first, then dark greys, fading out
# into the background. Model and effort, each coloured from green (the
# smallest model, the lowest effort) to red, then directory and git; then the
# context window and the 5-hour and weekly limits; then the vim mode, the
# output style and the session name, the lines on as few rows as the width
# takes. All text is tinted like its band and has a contrast of at
# least 4.6 against it. Reads the status line JSON on stdin and prints
# ANSI-coloured lines.
#
# The Windows twin of statusline.mjs, for the Claude Code install on Windows,
# where there is no Node to run that one. The lines are the same; keep the two
# in step. It runs under Windows PowerShell 5.1 and PowerShell 7 alike, and
# stays ASCII -- every other character is spelled as a code point -- because
# 5.1 reads a script without a byte order mark in the ANSI code page.
#
# The git band's counters come from `starship module git_status` with
# git-status.toml beside this file, in the background: at most one scan per
# repository at a time, a refresh during a scan only queues one rerun, and
# every refresh shows the last result. A `git fetch` runs the same way, at most
# every two minutes, so the commits to pull stay current. Either job shows an
# icon once it has run for two seconds. The jobs are this script again,
# started with -Scan or -Fetch.
#
# Usage, as the statusLine command in settings.json:
#   pwsh -NoProfile -File <checkout>\claude\.claude\status-band\statusline.ps1
param([string]$Scan, [string]$Fetch, [string]$Base)

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
$scanDir = Join-Path $stateDir 'git'
$gitStatusConfig = Join-Path $PSScriptRoot 'git-status.toml'

$fetchEveryMs = 2 * 60000
$slowMs = 2000

$esc = [char]27
$reset = "$esc[0m"
function Glyph([int]$Code) { [char]::ConvertFromUtf32($Code) }

# Muted colours on the prompt's One Half Dark, as in the .mjs. A coloured band
# has one brightness (2.0 against the background) and a text of its own hue at
# 4.6 against it; the scale runs green, lime, yellow, orange, red in even hue
# steps. The text colours for the dark bands reach 4.6 against `surface`.
$bands = @{
    green = @{ bg = @(72, 96, 64); text = @(181, 222, 167) }
    lime = @{ bg = @(87, 93, 62); text = @(205, 217, 155) }
    yellow = @{ bg = @(96, 89, 64); text = @(222, 210, 168) }
    orange = @{ bg = @(106, 85, 71); text = @(230, 205, 188) }
    red = @{ bg = @(118, 79, 84); text = @(235, 202, 207) }
    blue = @{ bg = @(72, 92, 109); text = @(193, 213, 231) }
    cyan = @{ bg = @(65, 94, 98); text = @(171, 218, 223) }
    grey = @{ bg = @(86, 90, 97); text = @(208, 211, 215) }
    purple = @{ bg = @(101, 81, 121); text = @(220, 204, 236) }
}
$colors = @{
    surface = @(62, 68, 81); deep = @(53, 58, 69); overlay = @(90, 99, 116)
    subtext = @(175, 179, 187); red = @(213, 167, 171); orange = @(201, 174, 147); yellow = @(215, 193, 152)
    green = @(161, 186, 142); cyan = @(140, 187, 193); blue = @(143, 183, 215); purple = @(201, 167, 211)
}
function Sgr([int]$Code, [int[]]$Rgb) { "$esc[$Code;2;$($Rgb -join ';')m" }
function Fg([string]$Name) { Sgr 38 $colors[$Name] }
function Bold([string]$Text) { "$esc[1m$Text$esc[22m" }
# JavaScript's Math.round, as Round-Half below.
function Mix([int[]]$A, [int[]]$B, [double]$T) {
    , @(0..2 | ForEach-Object { [int][Math]::Floor($A[$_] + ($B[$_] - $A[$_]) * $T + 0.5) })
}

# Green for the smallest model and the lowest effort, red for the largest and
# the highest.
$modelScale = @{ haiku = 'green'; sonnet = 'yellow'; opus = 'orange'; fable = 'red' }
$effortScale = @{ low = 'green'; medium = 'lime'; high = 'yellow'; xhigh = 'orange'; max = 'red' }

$glyphs = @{
    capLeft = Glyph 0xE0B6; arrow = Glyph 0xE0B0; thinArrow = Glyph 0xE0B1
    model = Glyph 0xF06C4; folder = Glyph 0xF024B; branch = Glyph 0xF418; commit = Glyph 0xF417
    context = Glyph 0xF035B; fiveHour = Glyph 0xF0150; weekly = Glyph 0xF0A33; style = Glyph 0xF03D8
    session = Glyph 0xF0EDE; fetching = Glyph 0xF063F; scanning = Glyph 0xF0C7D; vim = Glyph 0xE7C5
}
# Fills up with the level: low is almost empty, max is full.
$effortIcons = @{
    low = Glyph 0xF0A9F; medium = Glyph 0xF0AA1; high = Glyph 0xF0AA3; xhigh = Glyph 0xF0AA4; max = Glyph 0xF0AA5
}
$noEffortIcon = Glyph 0xF0A9E
$dash = [string][char]0x2013
# Cells of COLUMNS the status line cannot use: Claude Code indents it by two
# and keeps two free at the right edge.
$margin = 4
$gaugeChar = [string][char]0x2501

# One powerline strip: bands of @(rgb, text) joined by arrows, rounded at the
# start. An empty band is just its arrow, so the dark bands at the end always
# fade out in steps. Two bands of one colour (Opus at xhigh) are parted by a
# thin arrow in a lighter tint, since a full one would vanish. Whatever resets
# the background inside a band (the git counters do) is covered by setting it
# again before the band's last space.
function Strip([object[]]$Bands) {
    $out = "$(Sgr 38 $Bands[0][0])$($glyphs.capLeft)"
    for ($i = 0; $i -lt $Bands.Count; $i++) {
        $rgb = $Bands[$i][0]; $text = $Bands[$i][1]
        $out += "$(Sgr 48 $rgb)$text"
        if ($text) { $out += "$(Sgr 48 $rgb) " }
        if ($i + 1 -ge $Bands.Count) {
            $out += "$reset$(Sgr 38 $rgb)$($glyphs.arrow)$reset"
        } elseif (($Bands[$i + 1][0] -join ',') -eq ($rgb -join ',')) {
            $out += "$(Sgr 38 (Mix $rgb @(255, 255, 255) 0.3))$($glyphs.thinArrow)"
        } else {
            $out += "$(Sgr 38 $rgb)$(Sgr 48 $Bands[$i + 1][0])$($glyphs.arrow)"
        }
    }
    $out
}

# How many cells a strip takes: the cap, each band's text and closing space,
# and its arrow. Every glyph here is one cell wide; a surrogate pair is one.
function Cells([string]$Text) {
    $plain = $Text -replace "$esc\[[0-9;]*m", ''
    $plain.Length - [regex]::Matches($plain, '[\uDC00-\uDFFF]').Count
}

function Strip-Width($Bands) {
    $sum = 1
    foreach ($band in $Bands) { $sum += (Cells $band[1]) + $(if ($band[1]) { 2 } else { 1 }) }
    $sum
}

# The lines in order, as many on each row as fit in $Columns; a line that does
# not fit starts the next row whole. Two lines on one row are one strip: the
# first's empty fade is dropped, so its last band runs into the next line's
# first. The status-band mod folds its band the same way.
function Fold-Lines([object[]]$Lines, [int]$Columns) {
    $rows = [Collections.Generic.List[object]]::new()
    foreach ($line in $Lines) {
        if ($rows.Count -gt 0) {
            $last = $rows[$rows.Count - 1]
            $keep = if ($last.Count -gt 1 -and $last[$last.Count - 1][1] -eq '') { $last.Count - 1 } else { $last.Count }
            $joined = [Collections.Generic.List[object]]::new()
            for ($i = 0; $i -lt $keep; $i++) { $joined.Add($last[$i]) }
            foreach ($band in $line) { $joined.Add($band) }
            if ((Strip-Width $joined) -le $Columns) {
                $rows[$rows.Count - 1] = $joined.ToArray()
                continue
            }
        }
        $rows.Add($line)
    }
    , $rows.ToArray()
}

# A coloured band: its background, and the text in its own tint.
function Band([string]$Name, [string]$Text) {
    , @($bands[$Name].bg, "$(Sgr 38 $bands[$Name].text)$Text")
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

# The vim editor mode, which Claude Code sends only while vim mode is on; it
# draws no -- INSERT -- of its own (statusLine.hideVimModeIndicator). alt+i
# toggles vim mode, through the vim-toggle mod.
$vimModes = @{
    'NORMAL' = @('Normal', 'purple'); 'INSERT' = @('Insert', 'blue')
    'VISUAL' = @('Visual', 'orange'); 'VISUAL LINE' = @('Visual Line', 'orange')
}

function Vim-Band($Vim) {
    $mode = Prop $Vim 'mode'
    if ($mode -isnot [string]) { return , (Band 'grey' " $($glyphs.vim) vim off (alt+i)") }
    $found = $vimModes[$mode]
    if (-not $found) { $found = @($mode, 'grey') }
    , (Band $found[1] (Bold " $($glyphs.vim) $($found[0])"))
}

function Capitalize([string]$Word) {
    $Word.Substring(0, 1).ToUpperInvariant() + $Word.Substring(1).ToLowerInvariant()
}

$modelIdPattern = '(?i)(opus|sonnet|haiku|fable)-(\d+)(?:-(\d{1,2}))?(?:-\d{8})?$'

function Pretty-Model([string]$Id, [string]$DisplayName) {
    $isLongContext = $Id -match '\[1m\]'
    $bare = ($Id -replace '\[.*?\]', '').Trim()
    $name = if ($bare -match $modelIdPattern) {
        $minor = if ($Matches[3]) { ".$($Matches[3])" } else { '' }
        "$(Capitalize $Matches[1]) $($Matches[2])$minor"
    } elseif ($DisplayName) { $DisplayName } elseif ($bare) { $bare } else { 'unknown' }
    if ($isLongContext -and $name -notmatch '(?i)1m') { "$name (1M)" } else { $name }
}

function Model-Scale([string]$Id, [string]$DisplayName) {
    $bare = ($Id -replace '\[.*?\]', '').Trim()
    $family = if ($bare -match $modelIdPattern) { $Matches[1] }
              elseif ($DisplayName -match '(?i)opus|sonnet|haiku|fable') { $Matches[0] } else { '' }
    $scale = $modelScale[$family.ToLowerInvariant()]
    if ($scale) { $scale } else { 'grey' }
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

function Read-Text([string]$Path) {
    try { ([IO.File]::ReadAllText($Path)).Trim() } catch { $null }
}

# A git process with its arguments, killed after $TimeoutMs; its output, also
# when git fails (a new repository's HEAD makes rev-parse stop after the lines
# before it), or $null when it timed out.
function Run-Git([string]$Cwd, [string[]]$Arguments, [int]$TimeoutMs) {
    $info = New-Object Diagnostics.ProcessStartInfo 'git'
    $info.Arguments = (@('-C', "`"$Cwd`"") + $Arguments) -join ' '
    $info.UseShellExecute = $false
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.CreateNoWindow = $true
    $git = [Diagnostics.Process]::Start($info)
    $out = $git.StandardOutput.ReadToEndAsync()
    [void]$git.StandardError.ReadToEndAsync()
    if (-not $git.WaitForExit($TimeoutMs)) { try { $git.Kill() } catch {}; return $null }
    $out.Result
}

# What starship's git_state shows, from the files git leaves in its directory.
function Git-State([string]$GitDir) {
    function At([string]$Name) { Join-Path $GitDir $Name }
    function Progress([string]$Current, [string]$Total) {
        $c = Read-Text (At $Current); $t = Read-Text (At $Total)
        if ($c -and $t) { " $c/$t" } else { '' }
    }
    if (Test-Path -LiteralPath (At 'rebase-merge')) { return "REBASING$(Progress 'rebase-merge/msgnum' 'rebase-merge/end')" }
    if (Test-Path -LiteralPath (At 'rebase-apply')) {
        $kind = if (Test-Path -LiteralPath (At 'rebase-apply/rebasing')) { 'REBASING' }
                elseif (Test-Path -LiteralPath (At 'rebase-apply/applying')) { 'AM' } else { 'AM/REBASE' }
        return "$kind$(Progress 'rebase-apply/next' 'rebase-apply/last')"
    }
    if (Test-Path -LiteralPath (At 'MERGE_HEAD')) { return 'MERGING' }
    if (Test-Path -LiteralPath (At 'CHERRY_PICK_HEAD')) { return 'CHERRY-PICKING' }
    if (Test-Path -LiteralPath (At 'REVERT_HEAD')) { return 'REVERTING' }
    if (Test-Path -LiteralPath (At 'BISECT_LOG')) { return 'BISECTING' }
    $null
}

# One git call for the repository's root, its git directory and the short
# commit, with the .mjs's two-second limit; the branch is read from HEAD.
function Git-Head([string]$Cwd) {
    try {
        $out = Run-Git $Cwd @('rev-parse', '--show-toplevel', '--absolute-git-dir', '--short', 'HEAD') 2000
        if (-not $out) { return $null }
        $lines = @($out -split "`n" | ForEach-Object { $_.Trim() })
        if ($lines.Count -lt 2 -or -not $lines[0] -or -not $lines[1]) { return $null }
        $head = Read-Text (Join-Path $lines[1] 'HEAD')
        $branch = if ($head -match '^ref: refs/heads/(.+)$') { $Matches[1] } else { $null }
        $hash = if ($lines.Count -gt 2 -and $lines[2] -match '^[0-9a-f]+$') { $lines[2] } else { $null }
        @{ root = $lines[0]; branch = $branch; hash = $hash; state = (Git-State $lines[1]) }
    } catch { $null }
}

# A background job holds a lock file with its pid; one that died without
# removing it no longer counts.
function Job-Running([string]$Lock) {
    try {
        $text = Read-Text $Lock
        # Claimed but its pid not written yet: give the claimant a moment.
        if (-not $text) { return (([DateTime]::UtcNow - [IO.File]::GetLastWriteTimeUtc($Lock)).TotalSeconds -lt 10) }
        [bool](Get-Process -Id ([int]$text) -ErrorAction SilentlyContinue)
    } catch { $false }
}

# Running for longer than $slowMs, by the lock's age.
function Job-Slow([string]$Lock) {
    if (-not (Test-Path -LiteralPath $Lock)) { return $false }
    (([DateTime]::UtcNow - [IO.File]::GetLastWriteTimeUtc($Lock)).TotalMilliseconds -gt $slowMs) -and (Job-Running $Lock)
}

# Start this script with -MODE root -Base base in the background unless a job
# holds the lock; returns whether it started one.
function Start-Background([string]$Mode, [string]$Lock, [string]$Root, [string]$BasePath) {
    for ($attempt = 0; $attempt -lt 2; $attempt++) {
        try {
            $stream = [IO.File]::Open($Lock, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::Read)
        } catch {
            if (Job-Running $Lock) { return $false }
            Remove-Item -LiteralPath $Lock -Force -ErrorAction SilentlyContinue
            continue
        }
        try {
            $shell = (Get-Process -Id $PID).Path
            $arguments = @('-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"",
                "-$Mode", "`"$Root`"", '-Base', "`"$BasePath`"")
            $child = Start-Process -FilePath $shell -ArgumentList $arguments -WindowStyle Hidden -PassThru
            $bytes = $utf8.GetBytes([string]$child.Id)
            $stream.Write($bytes, 0, $bytes.Length)
        } finally {
            $stream.Dispose()
        }
        return $true
    }
    $false
}

# A scan during a scan only queues one rerun.
function Request-Scan([string]$Root, [string]$BasePath) {
    if (-not (Start-Background 'Scan' "$BasePath.lock" $Root $BasePath)) {
        [IO.File]::WriteAllText("$BasePath.rerun", '')
    }
}

# A fetch at most every $fetchEveryMs, counted from the last one's start, so a
# failing remote isn't retried on every refresh.
function Request-Fetch([string]$Root, [string]$BasePath) {
    $stamp = "$BasePath.fetched"
    if ((Test-Path -LiteralPath $stamp) -and
        ([DateTime]::UtcNow - [IO.File]::GetLastWriteTimeUtc($stamp)).TotalMilliseconds -lt $fetchEveryMs) { return }
    if (Start-Background 'Fetch' "$BasePath.fetch.lock" $Root $BasePath) { [IO.File]::WriteAllText($stamp, '') }
}

# The last counters for this repository and an icon for each slow job, and
# background jobs to refresh them.
function Git-Async([string]$Root) {
    $sha = [Security.Cryptography.SHA1]::Create()
    $hex = -join ($sha.ComputeHash($utf8.GetBytes($Root)) | ForEach-Object { $_.ToString('x2') })
    $basePath = Join-Path $scanDir $hex.Substring(0, 16)
    # Opened so that the scan can still swap a new result in meanwhile.
    $last = try {
        $file = [IO.File]::Open("$basePath.status", [IO.FileMode]::Open, [IO.FileAccess]::Read,
            [IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete)
        try { (New-Object IO.StreamReader($file, $utf8)).ReadToEnd() } finally { $file.Dispose() }
    } catch { '' }
    try {
        [void][IO.Directory]::CreateDirectory($scanDir)
        Request-Scan $Root $basePath
        Request-Fetch $Root $basePath
    } catch {}
    if (Job-Slow "$basePath.fetch.lock") { $last += "$(Fg 'cyan') $($glyphs.fetching)" }
    if (Job-Slow "$basePath.lock") { $last += "$(Fg 'yellow') $($glyphs.scanning)" }
    $last
}

# The git band's text, empty outside a repository.
function Git-Text([string]$Cwd) {
    $head = Git-Head $Cwd
    if ($null -eq $head) { return '' }
    $branch = if ($head.branch) { $head.branch } else { 'HEAD' }
    $text = "$(Fg 'purple') $($glyphs.branch) $branch"
    if ($head.hash) { $text += "$(Fg 'yellow') $($glyphs.commit) $($head.hash)" }
    if ($head.state) { $text += "$(Fg 'orange')$(Bold " $($head.state)")" }
    $text + (Git-Async $head.root)
}

function Compact-Tokens([double]$N) {
    if ($N -ge 1000000) { return ([Math]::Round($N / 1000000, 1, [MidpointRounding]::AwayFromZero)).ToString($inv) + 'M' }
    if ($N -ge 1000) { return "$(Round-Half ($N / 1000))k" }
    "$N"
}

# A slim gauge: the filled part in one colour, the rest in a quieter track.
function Gauge([double]$Percent, [int[]]$Color, [int[]]$Track, [int]$Width = 5) {
    $filled = [int][Math]::Min($Width, [Math]::Max(0, (Round-Half ($Percent / 100 * $Width))))
    "$(Sgr 38 $Color)$($gaugeChar * $filled)$(Sgr 38 $Track)$($gaugeChar * ($Width - $filled))"
}

function Used-Scale([double]$Percent) {
    if ($Percent -ge 80) { 'red' } elseif ($Percent -ge 50) { 'yellow' } else { 'green' }
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

# How much of a limit is left, and when it resets, as text for a dark band.
function Limit-Text([string]$Name, [string]$Icon, [hashtable]$Window) {
    $left = [Math]::Max(0, (Round-Half (100 - $Window.used)))
    "$(Fg 'blue') $Icon $Name $(Gauge $left $colors.blue $colors.overlay) " +
    "$(Fg 'blue')$(Bold "$left%") $(Fg 'subtext')$(Time-Until $Window.resetsAt)"
}

# How much of the context window is used: a band coloured by how full it is.
function Context-Band($Window) {
    $percent = Num (Prop $Window 'used_percentage')
    $size = Num (Prop $Window 'context_window_size')
    if ($null -eq $percent) {
        $text = if ($null -eq $size) { $dash } else { "$dash of $(Compact-Tokens $size)" }
        return Band 'grey' " $($glyphs.context) ctx $text"
    }
    $rounded = Round-Half $percent
    $band = $bands[(Used-Scale $rounded)]
    $gauge = Gauge $rounded $band.text (Mix $band.bg $band.text 0.3)
    , @($band.bg, "$(Sgr 38 $band.text) $($glyphs.context) ctx $gauge $(Sgr 38 $band.text)$(Bold "$rounded%")")
}

function Value-Or($Value, [string]$Color) {
    if ($null -eq $Value) { "$(Fg 'subtext') $dash" } else { "$(Fg $Color) $Value" }
}

# The status-band mod (claude/mods/status-band) draws these strips again as a
# band of buttons above the prompt. It learns what only this script is told
# (the vim mode, the effort, the session's name) from the input, written here
# per session with the effort and the limits as resolved above. While the mod
# runs it touches <session>.band every few seconds, and the strips are left
# to it; the git fetch still runs from here, so the commits to pull stay
# current.
#
# The mod's /status-band writes who draws the strips to status-band/mode: mod
# (the default) as above, band always here, off nowhere.
$sessionsDir = Join-Path $stateDir 'sessions'
$bandFreshMs = 20000
$modeFile = Join-Path $stateDir 'mode'

function Read-Mode {
    $mode = "$(Read-Text $modeFile)".ToLowerInvariant()
    if ($mode -eq 'band' -or $mode -eq 'off') { $mode } else { 'mod' }
}

function Session-File($Id, [string]$Suffix) {
    if ("$Id" -match '^[\w-]+$') { Join-Path $sessionsDir "$Id$Suffix" } else { $null }
}

# The input as it came, with `status_band` added before its closing brace.
function Feed-Band([string]$Raw, $Id, [hashtable]$Resolved) {
    $file = Session-File $Id '.json'
    $end = $Raw.LastIndexOf('}')
    if ($null -eq $file -or $end -lt 1) { return }
    try {
        [void][IO.Directory]::CreateDirectory($sessionsDir)
        $text = $Raw.Substring(0, $end).TrimEnd() + ',"status_band":' + ($Resolved | ConvertTo-Json -Compress) + '}'
        [IO.File]::WriteAllText("$file.tmp", $text, $utf8)
        Move-Item -LiteralPath "$file.tmp" -Destination $file -Force
        # Now and then, the files of sessions a week gone.
        if ((Get-Random -Maximum 100) -eq 0) {
            Get-ChildItem -LiteralPath $sessionsDir -File |
                Where-Object { $_.LastWriteTimeUtc -lt [DateTime]::UtcNow.AddDays(-7) } |
                Remove-Item -Force -ErrorAction SilentlyContinue
        }
    } catch {}
}

function Band-Live($Id) {
    $file = Session-File $Id '.band'
    if ($null -eq $file -or -not (Test-Path -LiteralPath $file)) { return $false }
    ([DateTime]::UtcNow - [IO.File]::GetLastWriteTimeUtc($file)).TotalMilliseconds -lt $bandFreshMs
}

function Fetch-Only([string]$Cwd) {
    $head = Git-Head $Cwd
    if ($null -eq $head) { return }
    try {
        $sha = [Security.Cryptography.SHA1]::Create()
        $hex = -join ($sha.ComputeHash($utf8.GetBytes($head.root)) | ForEach-Object { $_.ToString('x2') })
        [void][IO.Directory]::CreateDirectory($scanDir)
        Request-Fetch $head.root (Join-Path $scanDir $hex.Substring(0, 16))
    } catch {}
}

function Render($Data, [string]$Raw) {
    $model = Prop $Data 'model'
    $modelId = [string](Prop $model 'id')
    $displayName = [string](Prop $model 'display_name')
    $level = Prop (Prop $Data 'effort') 'level'
    if ($null -eq $level) { $level = Configured-Effort $modelId }
    if ($null -eq $level) { $level = 'default' }
    $effort = ([string]$level).ToLowerInvariant()
    $effortIcon = $effortIcons[$effort]
    if (-not $effortIcon) { $effortIcon = $noEffortIcon }
    $effortBand = $effortScale[$effort]
    if (-not $effortBand) { $effortBand = 'grey' }
    $cwd = Prop (Prop $Data 'workspace') 'current_dir'
    if (-not $cwd) { $cwd = Prop $Data 'cwd' }
    if (-not $cwd) { $cwd = (Get-Location).ProviderPath }
    $columns = 0
    if (-not [int]::TryParse($env:COLUMNS, [ref]$columns) -or $columns -le 0) { $columns = 80 }
    $columns -= $margin
    $cache = Read-Cache
    $limits = Prop $Data 'rate_limits'
    $fiveHour = Resolve-Window 'five_hour' (Prop $limits 'five_hour') $cache
    $weekly = Resolve-Window 'seven_day' (Prop $limits 'seven_day') $cache
    try {
        [void][IO.Directory]::CreateDirectory($stateDir)
        [IO.File]::WriteAllText($limitsCache, ($cache | ConvertTo-Json -Compress), $utf8)
    } catch {}
    $sessionId = Prop $Data 'session_id'
    Feed-Band $Raw $sessionId @{ effort = $level; five_hour = $fiveHour; seven_day = $weekly }
    $mode = Read-Mode
    if ($mode -eq 'off') { return '' }
    # The band draws the strips, so nothing here.
    if ($mode -eq 'mod' -and (Band-Live $sessionId)) {
        Fetch-Only $cwd
        return ''
    }

    $leaf =[IO.Path]::GetFileName($cwd.TrimEnd('\', '/'))
    # Each line fades out over the two dark greys; the git band is the first of
    # them, so outside a repository it is only the fade. The lines go on as few
    # rows as the width takes.
    $first = @(
        (Band (Model-Scale $modelId $displayName) (Bold " $($glyphs.model) $(Pretty-Model $modelId $displayName)")),
        (Band $effortBand " $effortIcon $level"),
        (Band 'blue' " $($glyphs.folder) $(if ($leaf) { $leaf } else { $cwd })"),
        @($colors.surface, (Git-Text $cwd)),
        @($colors.deep, '')
    )
    $second = @(
        (Context-Band (Prop $Data 'context_window')),
        @($colors.surface, (Limit-Text '5h' $glyphs.fiveHour $fiveHour)),
        @($colors.surface, (Limit-Text '7d' $glyphs.weekly $weekly))
    )
    # Claude Code sends session_name only once the session has one (/rename).
    $style = Prop (Prop $Data 'output_style') 'name'
    $third = @(
        (Vim-Band (Prop $Data 'vim')),
        (Band 'cyan' " $($glyphs.style) $(if ($null -ne $style) { $style } else { $dash })"),
        @($colors.surface, "$(Fg 'yellow') $($glyphs.session)$(Value-Or (Prop $Data 'session_name') 'yellow')"),
        @($colors.deep, '')
    )

    $rows = Fold-Lines @($first, $second, $third) $columns
    @(foreach ($row in $rows) { Strip $row }) -join "`n"
}

# The background side: scan, and scan again while refreshes asked for it.
# GIT_OPTIONAL_LOCKS=0 keeps `git status` from holding .git/index.lock, which
# would make your own git commands fail while it runs.
if ($Scan) {
    $rerun = "$Base.rerun"
    $ErrorActionPreference = 'Continue'
    try {
        $env:STARSHIP_CONFIG = $gitStatusConfig
        $env:GIT_OPTIONAL_LOCKS = '0'
        Remove-Item Env:STARSHIP_SHELL -ErrorAction SilentlyContinue
        do {
            Remove-Item -LiteralPath $rerun -Force -ErrorAction SilentlyContinue
            $out = (& starship module git_status --path $Scan 2>$null) -join "`n"
            [IO.File]::WriteAllText("$Base.tmp", $out, $utf8)
            # A render reading the last result blocks the swap for a moment.
            for ($try = 1; ; $try++) {
                try {
                    if (Test-Path -LiteralPath "$Base.status") {
                        # [NullString]: a plain $null reaches .NET as "", an empty backup path.
                        [IO.File]::Replace("$Base.tmp", "$Base.status", [NullString]::Value)
                    } else {
                        [IO.File]::Move("$Base.tmp", "$Base.status")
                    }
                    break
                } catch {
                    if ($try -ge 20) { throw }
                    Start-Sleep -Milliseconds 50
                }
            }
        } while (Test-Path -LiteralPath $rerun)
    } catch {
    } finally {
        Remove-Item -LiteralPath "$Base.lock" -Force -ErrorAction SilentlyContinue
    }
    exit 0
}

# The other background side: fetch, then scan so the counters show the new
# commits to pull. Nothing may prompt: no terminal, no credential window, no
# ssh passphrase; a remote that would need one just isn't fetched.
if ($Fetch) {
    $ErrorActionPreference = 'Continue'
    try {
        $env:GIT_TERMINAL_PROMPT = '0'
        $env:GCM_INTERACTIVE = 'never'
        $sshCommand = Run-Git $Fetch @('config', 'core.sshCommand') 10000
        if (-not "$sshCommand".Trim() -and -not $env:GIT_SSH_COMMAND) { $env:GIT_SSH_COMMAND = 'ssh -o BatchMode=yes' }
        [void](Run-Git $Fetch @('fetch', '--quiet') 120000)
    } catch {
    } finally {
        Remove-Item -LiteralPath "$Base.fetch.lock" -Force -ErrorAction SilentlyContinue
    }
    try { Request-Scan $Fetch $Base } catch {}
    exit 0
}

$data = $null
$raw = ''
try {
    $raw = [Console]::In.ReadToEnd()
    $data = $raw | ConvertFrom-Json
} catch {}
[Console]::Out.Write((Render $data $raw))
