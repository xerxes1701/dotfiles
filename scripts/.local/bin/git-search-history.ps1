<#
.SYNOPSIS
    Search a git repository's history for a regex in the content that commits
    changed, over a range given by date, by commit, or by both.

.DESCRIPTION
    A wrapper around git's pickaxe, `git log -G<regex>`: it walks the diff of
    every commit in the range and keeps the commits where a line matching the
    pattern was added or removed. `git grep` only ever sees one snapshot - the
    working tree or one revision - so it cannot answer "when did this string
    appear, and when did it go away again"; this can, and it finds text that no
    longer exists anywhere in the tree.

    Each matching commit is printed with its subject, then the files it touched
    and the added (+) and removed (-) lines that match, with the match itself
    highlighted inside the line. -PassThru additionally puts one object per
    commit on the pipeline, so the same call can feed a report.

    Ranges narrow independently and may be combined: -SinceDate/-UntilDate
    become git's --since/--until (committer date), -FromCommit/-ToCommit become
    a revision range. Both ends are inclusive - -FromCommit itself is searched,
    unlike git's own `A..B` - and either end may be left out, in which case the
    history's start or HEAD takes its place.

.PARAMETER Pattern
    The regex. git matches it with the flavour -RegexFlavor selects; the same
    pattern is compiled as a .NET regex to pick the matching lines out of the
    diff and to highlight them, so stick to constructs both understand.

.PARAMETER RepositoryPath
    Repository to search, anywhere inside its working tree. Defaults to the
    current directory.

.PARAMETER SinceDate
    Start of the date range, inclusive. Anything PowerShell parses as a date,
    e.g. '2026-01-31', '2026-01-31 18:00' or (Get-Date).AddMonths(-3).

.PARAMETER UntilDate
    End of the date range, inclusive.

.PARAMETER FromCommit
    Start of the commit range, inclusive: a sha, tag, branch or any other
    revision git resolves (HEAD~20, v1.2^, origin/main).

.PARAMETER ToCommit
    End of the commit range, inclusive. Defaults to HEAD.

.PARAMETER PathSpec
    Limit the search to these paths, as git pathspecs ('*.ps1', 'src/').

.PARAMETER Author
    Only commits whose author matches this pattern, git's --author.

.PARAMETER MaxCount
    Stop after this many matching commits.

.PARAMETER RegexFlavor
    Which regex dialect git uses: Perl (--perl-regexp, needs a git built with
    PCRE, the default because it is the dialect closest to .NET), Extended
    (--extended-regexp, git's own default) or Basic (--basic-regexp).

.PARAMETER IgnoreCase
    Match without regard to case, in git and in the highlighting.

.PARAMETER AllRefs
    Search every ref instead of the current branch. Cannot be combined with
    -FromCommit/-ToCommit, which name a range of their own.

.PARAMETER NoDiff
    List the matching commits only, without the matching lines. Much faster on
    a wide range: the diff of each hit does not have to be produced.

.PARAMETER NoColor
    Force plain output. Colour is off by itself when stdout is redirected or
    NO_COLOR is set.

.PARAMETER PassThru
    Also emit one object per commit (Commit, Author, Date, Subject, Matches) on
    the pipeline.

.EXAMPLE
    git-search-history.ps1 'AKIA[0-9A-Z]{16}'

    Every commit on the current branch that added or removed an AWS key id.

.EXAMPLE
    git-search-history.ps1 -Pattern 'ConnectionString' -SinceDate 2026-01-01 -UntilDate 2026-06-30 -PathSpec '*.cs'

    Half a year of C# changes touching the connection string.

.EXAMPLE
    git-search-history.ps1 'TODO\(perf\)' -FromCommit v2.3.0 -ToCommit main -MaxCount 20

    The first 20 hits between a tag and a branch tip, both ends included.

.EXAMPLE
    git-search-history.ps1 'password' -SinceDate (Get-Date).AddDays(-30) -PassThru | Export-Csv hits.csv

    Colour report on screen, objects into a CSV.

.NOTES
    There is no shebang and #Requires sits below the help: Get-Help only finds
    a script's comment-based help when the block is the first thing in the
    file. Run it through pwsh - `pwsh -File git-search-history.ps1 ...` - or
    dot-slash it on Windows, where .ps1 is associated.

    Exit codes: 0 commits found, 1 none found, 2 bad arguments or a failing git.

    The date range filters on committer date, which is what git's --since and
    --until look at; it is not always the author date shown by other tools.

    Merge commits are not searched. The pickaxe compares against the first
    parent only and git omits them, so a change that entered the branch through
    a merge is reported on the commit that made it.
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string] $Pattern,

    [Parameter(Position = 1)]
    [Alias('Repo')]
    [ValidateNotNullOrEmpty()]
    [string] $RepositoryPath = '.',

    [Alias('Since')]
    [Nullable[datetime]] $SinceDate,

    [Alias('Until')]
    [Nullable[datetime]] $UntilDate,

    [Alias('From')]
    [ValidateNotNullOrEmpty()]
    [string] $FromCommit,

    [Alias('To')]
    [ValidateNotNullOrEmpty()]
    [string] $ToCommit,

    [Alias('Include')]
    [ValidateNotNullOrEmpty()]
    [string[]] $PathSpec,

    [ValidateNotNullOrEmpty()]
    [string] $Author,

    [ValidateRange(1, 100000)]
    [int] $MaxCount,

    [ValidateSet('Perl', 'Extended', 'Basic')]
    [string] $RegexFlavor = 'Perl',

    [switch] $IgnoreCase,
    [switch] $AllRefs,
    [switch] $NoDiff,
    [switch] $NoColor,
    [switch] $PassThru
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

# PowerShell 7.3+ turns a non-zero exit of a native command into a terminating
# error under ErrorActionPreference Stop. git's exit codes are part of its
# answer here, so they are read, not thrown.
$PSNativeCommandUseErrorActionPreference = $false

# git speaks UTF-8; without this an umlaut in a path or a diff line arrives
# mangled in Windows PowerShell.
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

$Self = 'git-search-history.ps1'
if ($PSCommandPath) { $Self = [System.IO.Path]::GetFileName($PSCommandPath) }

# Colour is for a human looking at a terminal: a redirected stdout gets the
# plain text, and NO_COLOR (https://no-color.org) is honoured.
$UseColor = -not $NoColor -and -not $env:NO_COLOR -and -not [Console]::IsOutputRedirected

function Write-Plain {
    param(
        [string] $Text = '',
        [string] $Color,
        [string] $Background,
        [switch] $NoNewline
    )
    $splat = @{ Object = $Text; NoNewline = [bool]$NoNewline }
    if ($UseColor -and $Color) { $splat.ForegroundColor = $Color }
    if ($UseColor -and $Background) { $splat.BackgroundColor = $Background }
    Write-Host @splat
}

function Write-Fail {
    param([string] $Message, [int] $Code = 2)
    if ($UseColor) { Write-Plain "$Self`: $Message" Red }
    else { [Console]::Error.WriteLine("$Self`: $Message") }
    exit $Code
}

function Write-Note {
    param([string] $Message)
    if ($UseColor) { Write-Plain "$Self`: $Message" Yellow }
    else { [Console]::Error.WriteLine("$Self`: $Message") }
}

# Runs git and hands back its stdout lines, its stderr and its exit code, so
# every caller can decide for itself whether a failure is fatal.
function Invoke-Git {
    param([string[]] $Arguments)

    $merged = & $GitExe @Arguments 2>&1
    $code = $LASTEXITCODE
    $out = New-Object System.Collections.Generic.List[string]
    $err = New-Object System.Collections.Generic.List[string]
    foreach ($record in $merged) {
        if ($record -is [System.Management.Automation.ErrorRecord]) { $err.Add([string]$record) }
        else { $out.Add([string]$record) }
    }
    [pscustomobject]@{ Output = $out; Error = ($err -join [Environment]::NewLine); ExitCode = $code }
}

# --- parameter verification -------------------------------------------------

$git = Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $git) { Write-Fail 'git was not found on PATH.' }
$GitExe = $git.Source

if (-not (Test-Path -LiteralPath $RepositoryPath)) {
    Write-Fail "-RepositoryPath does not exist: $RepositoryPath"
}
$repoPath = (Resolve-Path -LiteralPath $RepositoryPath).ProviderPath

# core.quotepath=false keeps non-ASCII file names readable instead of \303\244.
$GitBase = @('--no-pager', '-C', $repoPath, '-c', 'core.quotepath=false')

$top = Invoke-Git ($GitBase + @('rev-parse', '--show-toplevel'))
if ($top.ExitCode -ne 0 -or $top.Output.Count -eq 0) {
    Write-Fail "not a git repository: $repoPath"
}
$repoRoot = $top.Output[0]

if ($SinceDate -and $UntilDate -and $SinceDate -gt $UntilDate) {
    Write-Fail ('-SinceDate ({0:yyyy-MM-dd HH:mm}) is later than -UntilDate ({1:yyyy-MM-dd HH:mm}).' -f $SinceDate, $UntilDate)
}

if ($AllRefs -and ($FromCommit -or $ToCommit)) {
    Write-Fail '-AllRefs searches every ref and cannot be combined with -FromCommit/-ToCommit.'
}

# Resolve both ends to a full sha, which also verifies they exist and are
# commits: a tag object or a tree would otherwise fail much later.
function Resolve-Commit {
    param([string] $Revision, [string] $ParameterName)

    $rev = Invoke-Git ($GitBase + @('rev-parse', '--verify', '--quiet', "$Revision^{commit}"))
    if ($rev.ExitCode -ne 0 -or $rev.Output.Count -eq 0) {
        Write-Fail "$ParameterName is not a commit in this repository: $Revision"
    }
    $rev.Output[0]
}

$fromSha = $null
$toSha = $null
if ($FromCommit) { $fromSha = Resolve-Commit $FromCommit '-FromCommit' }
if ($ToCommit) { $toSha = Resolve-Commit $ToCommit '-ToCommit' }

if ($fromSha -and $toSha) {
    $anc = Invoke-Git ($GitBase + @('merge-base', '--is-ancestor', $fromSha, $toSha))
    if ($anc.ExitCode -ne 0) {
        Write-Note "-FromCommit is not an ancestor of -ToCommit; the range covers only what -ToCommit can reach."
    }
}

# The pattern is compiled twice over: git matches it while walking history, and
# .NET picks the matching lines out of the resulting diffs. Only the .NET side
# can be checked up front - a syntax error in git's flavour surfaces as a
# failing git run below, with git's own message.
$rxOptions = [System.Text.RegularExpressions.RegexOptions]::None
if ($IgnoreCase) { $rxOptions = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase }
$matcher = $null
try {
    $matcher = [regex]::new($Pattern, $rxOptions)
}
catch {
    # The real complaint sits in the inner ArgumentException; the outer one is
    # PowerShell reporting that a constructor threw.
    $reason = $_.Exception.Message
    if ($_.Exception.InnerException) { $reason = $_.Exception.InnerException.Message }
    if ($RegexFlavor -eq 'Perl') {
        Write-Fail "-Pattern is not a valid regex: $reason"
    }
    # Basic and Extended have constructs .NET reads differently, e.g. \( for a
    # group. git can still run; only the per-line detail has to go.
    Write-Note "-Pattern does not compile as a .NET regex, so the matching lines cannot be picked out; listing commits only."
    $NoDiff = $true
}

# --- the history walk -------------------------------------------------------

# A unit separator keeps the fields apart: it cannot occur in a commit subject.
$FS = [char]0x1f
$logArgs = $GitBase + @('log', '--no-color', '--format=%H%x1f%an%x1f%aI%x1f%cI%x1f%s')

switch ($RegexFlavor) {
    'Perl' { $logArgs += '--perl-regexp' }
    'Extended' { $logArgs += '--extended-regexp' }
    'Basic' { $logArgs += '--basic-regexp' }
}
if ($IgnoreCase) { $logArgs += '--regexp-ignore-case' }
$logArgs += "-G$Pattern"

if ($SinceDate) { $logArgs += '--since=' + $SinceDate.ToString('yyyy-MM-ddTHH:mm:sszzz', [cultureinfo]::InvariantCulture) }
if ($UntilDate) { $logArgs += '--until=' + $UntilDate.ToString('yyyy-MM-ddTHH:mm:sszzz', [cultureinfo]::InvariantCulture) }
if ($Author) { $logArgs += "--author=$Author" }
if ($MaxCount) { $logArgs += "--max-count=$MaxCount" }

# Both ends inclusive. git's own A..B leaves A out, so instead of excluding A
# the range excludes A's parents - which for a root commit is nothing at all,
# exactly the wanted result.
if ($AllRefs) {
    $logArgs += '--all'
}
else {
    $logArgs += $(if ($toSha) { $toSha } else { 'HEAD' })
    if ($fromSha) { $logArgs += @('--not', "$fromSha^@") }
}

$pathArgs = @()
if ($PathSpec) { $pathArgs = @('--') + $PathSpec }

$log = Invoke-Git ($logArgs + $pathArgs)
if ($log.ExitCode -ne 0) {
    $message = if ($log.Error) { $log.Error } else { "git log failed with exit code $($log.ExitCode)." }
    if ($RegexFlavor -eq 'Perl' -and $message -match 'Perl|PCRE') {
        $message += [Environment]::NewLine + "This git was built without PCRE; retry with -RegexFlavor Extended."
    }
    Write-Fail $message
}

# --- the matching lines of one commit ---------------------------------------

# Reads a commit's diff and keeps the added and removed lines the pattern
# matches, each with the line number it has in its version of the file.
function Get-CommitMatch {
    param([string] $Sha)

    $showArgs = $GitBase + @('show', '--no-color', '--format=', '--unified=0', $Sha) + $pathArgs
    $show = Invoke-Git $showArgs
    if ($show.ExitCode -ne 0) {
        Write-Note "cannot read the diff of $($Sha.Substring(0, 8)): $($show.Error)"
        return @()
    }

    $hits = New-Object System.Collections.Generic.List[object]
    $oldPath = $null
    $file = $null
    $oldLine = 0
    $newLine = 0

    foreach ($line in $show.Output) {
        if ($line.StartsWith('--- ')) {
            $p = $line.Substring(4)
            $oldPath = $(if ($p -eq '/dev/null') { $null } else { $p -replace '^a/', '' })
            continue
        }
        if ($line.StartsWith('+++ ')) {
            $p = $line.Substring(4)
            $file = $(if ($p -eq '/dev/null') { $oldPath } else { $p -replace '^b/', '' })
            continue
        }
        if ($line.StartsWith('@@')) {
            $m = [regex]::Match($line, '^@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@')
            if ($m.Success) {
                $oldLine = [int]$m.Groups[1].Value
                $newLine = [int]$m.Groups[2].Value
            }
            continue
        }
        # Everything before the first hunk is header: the diff --git, index,
        # mode and similarity lines, and the commit message when a format asks
        # for one. None of it is content.
        if (-not $file -or $line.Length -eq 0) { continue }

        switch ($line.Substring(0, 1)) {
            '+' {
                $text = $line.Substring(1)
                if ($matcher.IsMatch($text)) {
                    $hits.Add([pscustomobject]@{ File = $file; Line = $newLine; Kind = 'added'; Text = $text })
                }
                $newLine++
            }
            '-' {
                $text = $line.Substring(1)
                if ($matcher.IsMatch($text)) {
                    $hits.Add([pscustomobject]@{ File = $file; Line = $oldLine; Kind = 'removed'; Text = $text })
                }
                $oldLine++
            }
            ' ' { $oldLine++; $newLine++ }
        }
    }
    , $hits.ToArray()
}

# Writes one diff line, the part the pattern matched inverted inside it.
function Write-MatchLine {
    param([string] $Sign, [int] $Number, [string] $Text, [string] $Color)

    Write-Plain ('    {0} {1,6}  ' -f $Sign, $Number) DarkGray -NoNewline
    $cursor = 0
    foreach ($m in $matcher.Matches($Text)) {
        if ($m.Index -gt $cursor) {
            Write-Plain $Text.Substring($cursor, $m.Index - $cursor) $Color -NoNewline
        }
        # A zero-length match (an anchor, a lookaround) has nothing to invert.
        if ($m.Length -gt 0) {
            Write-Plain $m.Value Black $Color -NoNewline
        }
        $cursor = $m.Index + $m.Length
    }
    Write-Plain $Text.Substring($cursor) $Color
}

# --- report -----------------------------------------------------------------

$commits = 0
$lines = 0

foreach ($record in $log.Output) {
    if (-not $record) { continue }
    $field = $record.Split($FS)
    if ($field.Count -lt 5) { continue }

    $sha = $field[0]
    $author = $field[1]
    $authored = $field[2]
    $committed = $field[3]
    $subject = $field[4]
    $commits++

    $date = $authored
    try { $date = ([datetimeoffset]$authored).ToString('yyyy-MM-dd HH:mm', [cultureinfo]::InvariantCulture) } catch { }

    Write-Plain ''
    Write-Plain $sha.Substring(0, 12) Yellow -NoNewline
    Write-Plain "  $date  " DarkGray -NoNewline
    Write-Plain $author Cyan
    Write-Plain "  $subject" White

    $hits = @()
    if (-not $NoDiff) {
        $hits = Get-CommitMatch $sha
        $lines += $hits.Count
        $currentFile = $null
        foreach ($hit in $hits) {
            if ($hit.File -ne $currentFile) {
                $currentFile = $hit.File
                Write-Plain "  $currentFile" Magenta
            }
            if ($hit.Kind -eq 'added') { Write-MatchLine '+' $hit.Line $hit.Text Green }
            else { Write-MatchLine '-' $hit.Line $hit.Text Red }
        }
        # The pickaxe found the commit, so something matched; when nothing
        # shows up here the two regex flavours disagree about the pattern.
        if ($hits.Count -eq 0) {
            Write-Plain '  (git matched this commit, but the .NET regex matches none of its diff lines)' DarkGray
        }
    }

    if ($PassThru) {
        [pscustomobject]@{
            Commit       = $sha
            Author       = $author
            Date         = $authored
            CommitDate   = $committed
            Subject      = $subject
            Repository   = $repoRoot
            MatchedLines = $hits.Count
            Matches      = $hits
        }
    }
}

Write-Plain ''
if ($commits -eq 0) {
    Write-Plain "no commit in this range changed a line matching /$Pattern/" DarkGray
    exit 1
}

$summary = "$commits commit$(if ($commits -ne 1) { 's' })"
if (-not $NoDiff) { $summary += ", $lines matching line$(if ($lines -ne 1) { 's' })" }
Write-Plain $summary Cyan
exit 0
