#Requires -Version 5.1
<#
.SYNOPSIS
    Deploy this repository's Windows packages into the user profile, on an
    account that cannot create symlinks.

.DESCRIPTION
    The no-admin fallback for stow-deploy-windows.sh. Prefer that launcher
    wherever it runs: stow is the mechanism every other machine here uses,
    and one mechanism is one set of failure modes. It needs a symlink, and
    creating one needs SeCreateSymbolicLinkPrivilege, which only elevation or
    Developer Mode grants -- hence this script, and hence its name: a work
    machine whose account is neither an administrator nor a developer.

    Both deploys leave the same layout behind, so that nothing which reads a
    config has to know which one ran. Same packages, same paths, same keys:

      stow-deploy-windows.sh            deploy-windows-noadmin.ps1
      ~\.config\<pkg>        symlink    ~\.config\<pkg>       junction
      ~\.local\bin\<file>    symlinks   ~\.local\bin          junction
      ~\.config\herdr\...    symlink    HERDR_CONFIG_PATH
      ~\.gitconfig           symlink    ~\.gitconfig          include stub
      ~\.config\starship...  symlink    STARSHIP_CONFIG

    It deploys the packages that Windows programs read and leaves the ones
    for fish, tmux, zellij and the rest of the Linux side alone -- the list,
    and the reason for each entry, is the $Packages table below.

    Two things need no privilege at all and cover every package here:

      junction  a directory package -- nvim, wezterm, scripts, ... -- is one
                NTFS junction from the profile into the repository, which is
                exactly the folded link stow makes for it on Linux.
      env var   a single-file package -- starship.toml, whkdrc -- is pointed
                at with the variable its tool reads (STARSHIP_CONFIG,
                WHKD_CONFIG_HOME); git gets a two-line ~\.gitconfig that
                includes the repository's, because TortoiseGit and other
                libgit2 clients read the file and not GIT_CONFIG_GLOBAL.

    XDG_CONFIG_HOME is set to ~\.config on top, so that nvim, nushell, scoop
    and fastfetch look there instead of under AppData, and the repository's
    .config\<name> layout maps one to one.

    Environment variables are written to the user environment (HKCU), so a
    terminal opened after the deploy sees them; one that is already open does
    not. With -Target pointing anywhere but the profile they are set for this
    process only, which is what makes a rehearsal harmless.

    Nothing is changed when anything is in the way: every conflict is listed
    first, with what to do about it, and the script exits.

.PARAMETER Package
    Deploy only these packages. Default: every package in the table.

.PARAMETER Target
    Where to deploy. Default: the user profile.

.PARAMETER Remove
    Remove what a deploy created -- junctions and the .gitconfig stub owned
    by this repository, and the environment variables -- instead of creating
    it. Files that are not the script's own are left alone.

.PARAMETER DryRun
    Print what would happen and change nothing. -n for short.

.PARAMETER List
    List the packages this script deploys, and exit.

.EXAMPLE
    scripts\.local\bin\deploy-windows-noadmin.ps1

.EXAMPLE
    scripts\.local\bin\deploy-windows-noadmin.ps1 -n

.EXAMPLE
    scripts\.local\bin\deploy-windows-noadmin.ps1 nvim wezterm

.EXAMPLE
    scripts\.local\bin\deploy-windows-noadmin.ps1 -Remove

.NOTES
    The two Windows deploys write the same paths, so a machine only ever has
    one of them: let go of the other first, with `stow-deploy-windows.sh -D`
    or `deploy-windows-noadmin.ps1 -Remove`. Each reports the other's links
    as a conflict rather than replacing them.

    A junction resolves on the Windows side only: git run inside
    ~\.config\nvim does not find this repository, because Windows reports the
    junction path as the working directory and there is no .git above it.
    Run git in the repository itself.

    If the machine policy blocks running scripts:
        powershell -ExecutionPolicy Bypass -File scripts\.local\bin\deploy-windows-noadmin.ps1
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
    [string[]] $Package = @(),
    [string] $Target = $env:USERPROFILE,
    [switch] $Remove,
    [Alias('n')]
    [switch] $DryRun,
    [switch] $List
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

# --- packages --------------------------------------------------------------
#
# Junction  path under the target that becomes a junction, or several of
#           them; the source is the same path under the package, so the
#           package has to be laid out for ~ the way every stow package here
#           is.
# Env       variables to set. {repo} and {target} are replaced.
# Include   a git config stub at that path, including the named file.
#
# herdr deploys from the hidden .herdr-windows package, not from herdr/: the
# host config is Linux (fish, nvim plugin keys, bash helpers), see the header
# of the Windows one. It is pointed at rather than junctioned because herdr
# writes its socket, logs and session next to its config.
#
# scripts is deployed although most of it is bash: the Windows herdr config
# and nvim's smart-splits spec call the .ps1 twins by full path under
# %USERPROFILE%\.local\bin, which is where stow-deploy-windows.sh puts them,
# so the fallback has to put them there too or those keys reach nothing. stow
# stows the package unfolded, one link per file; a junction is per directory,
# so ~\.local\bin belongs to the repository here and whatever else writes
# into it lands in the working tree. ~\.local\lib stays a real directory --
# only its dotfiles\ is junctioned -- which is the reason the package is in
# stow-deploy.sh's unfolded list.
#
# Not here, and why:
#   claude   ~\.claude on Windows is a separate Claude Code install with its
#            own settings.json and a PowerShell hook; the package's hook and
#            status line are bash and bun.
#   fish, zsh, tmux, tmux-powerline, tmuxinator, zellij, niri, xkb, gtk-3.0,
#   ghostty, vale, images  -- Linux programs, or files only they read.
$Packages = [ordered]@{
    nvim      = @{ Junction = '.config\nvim' }
    wezterm   = @{ Junction = '.config\wezterm' }
    komorebi  = @{ Junction = '.config\komorebi'
                   Env = @{ KOMOREBI_CONFIG_HOME = '{target}\.config\komorebi' } }
    whkd      = @{ Env = @{ WHKD_CONFIG_HOME = '{repo}\whkd\.config' } }
    kmonad    = @{ Junction = '.config\kmonad' }
    scoop     = @{ Junction = '.config\scoop' }
    nushell   = @{ Junction = '.config\nushell' }
    yazi      = @{ Junction = '.config\yazi'
                   Env = @{ YAZI_CONFIG_HOME = '{target}\.config\yazi' } }
    fastfetch = @{ Junction = '.config\fastfetch' }
    bat       = @{ Junction = '.config\bat'
                   Env = @{ BAT_CONFIG_DIR = '{target}\.config\bat' } }
    scripts   = @{ Junction = @('.local\bin', '.local\lib\dotfiles') }
    starship  = @{ Env = @{ STARSHIP_CONFIG = '{repo}\starship\.config\starship.toml' } }
    git       = @{ Include = @{ File = '.gitconfig'; Path = '{repo}\git\.gitconfig' } }
    herdr     = @{ Env = @{ HERDR_CONFIG_PATH = '{repo}\.herdr-windows\.config\herdr\config.toml' } }
}

# Set with every deploy and removed only by a full -Remove: more than one
# package relies on it, so removing a single package must not take it away.
$BaseEnv = @{ XDG_CONFIG_HOME = '{target}\.config' }

$StubMarker = '# written by deploy-windows-noadmin.ps1'

# --- output ----------------------------------------------------------------

function Write-Err  { param($m) Write-Host "error: $m" -ForegroundColor Red }
function Write-Hint { param($m) Write-Host "  $m" -ForegroundColor DarkGray }
function Write-Note { param($m) Write-Host $m -ForegroundColor Cyan }
function Write-Step { param($m) Write-Host "+ $m" -ForegroundColor DarkGray }

function Fail {
    param([string] $Message, [string[]] $Hints = @())
    Write-Err $Message
    foreach ($h in $Hints) { Write-Hint $h }
    exit 1
}

# --- environment -----------------------------------------------------------

if ($env:OS -ne 'Windows_NT') {
    Fail 'this is not Windows' 'on Linux and in WSL run stow-deploy.sh instead'
}

# scripts\.local\bin is three levels below the repository.
$Repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path.TrimEnd('\')
if ($Repo -notmatch '^[A-Za-z]:\\') {
    Fail "the repository is at $Repo, which is not on a local drive" `
        'a junction cannot point at a UNC or \\wsl.localhost path' `
        'clone the repository under the Windows profile and deploy from there'
}

$Target = $Target.TrimEnd('\')
if (-not (Test-Path -LiteralPath $Target -PathType Container)) {
    Fail "the target $Target is not a directory" 'pass an existing directory with -Target'
}
$RealProfile = ($Target -ieq $env:USERPROFILE.TrimEnd('\'))
$EnvScope = if ($RealProfile) { 'User' } else { 'Process' }

function Expand-Placeholders {
    param([string] $s)
    $s.Replace('{repo}', $Repo).Replace('{target}', $Target)
}

# A reparse point's target as .NET reports it, minus the \\?\ prefix newer
# PowerShell versions put in front of a junction's.
function Get-LinkTarget {
    param([System.IO.FileSystemInfo] $item)
    $t = @($item.Target)[0]
    if ($null -eq $t) { return $null }
    $t = "$t"
    if ($t.StartsWith('\\?\')) { $t = $t.Substring(4) }
    $t.TrimEnd('\')
}

function Test-ReparsePoint {
    param([System.IO.FileSystemInfo] $item)
    ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0
}

# --- selection -------------------------------------------------------------

$Selected = [ordered]@{}
if ($Package.Count -gt 0) {
    foreach ($p in $Package) {
        if (-not $Packages.Contains($p)) {
            $reason = if (Test-Path -LiteralPath (Join-Path $Repo $p) -PathType Container) {
                "$p is a package of the repository, but not one Windows deploys -- see the table in this script"
            } else {
                "$Repo has no package $p"
            }
            Fail $reason 'run with -List to see the packages this script deploys'
        }
        $Selected[$p] = $Packages[$p]
    }
} else {
    foreach ($p in $Packages.Keys) { $Selected[$p] = $Packages[$p] }
}
$FullSet = ($Package.Count -eq 0)

if ($List) {
    Write-Host "$Repo -> $Target" -ForegroundColor White
    foreach ($p in $Selected.Keys) {
        $spec = $Selected[$p]
        $how = @()
        if ($spec.Contains('Junction')) {
            $how += @($spec.Junction | ForEach-Object { "junction $_" })
        }
        if ($spec.Contains('Env'))      { $how += ($spec.Env.Keys | ForEach-Object { "env $_" }) }
        if ($spec.Contains('Include'))  { $how += "include stub $($spec.Include.File)" }
        Write-Host ("  {0,-12} {1}" -f $p, ($how -join ', '))
    }
    Write-Host ("  {0,-12} {1}" -f '(always)', 'env XDG_CONFIG_HOME') -ForegroundColor DarkGray
    exit 0
}

# --- plan ------------------------------------------------------------------
#
# Every action is worked out and checked before anything is touched, so a
# conflict in the last package cannot leave the first ones half deployed.

$Actions   = New-Object System.Collections.ArrayList
$Conflicts = New-Object System.Collections.ArrayList

function Add-Action {
    param([string] $Kind, [string] $Text, [hashtable] $With = @{})
    [void] $Actions.Add(@{ Kind = $Kind; Text = $Text; With = $With })
}

# One place that touches the file system and the registry. The plan holds
# data, not script blocks: a closure runs in its own module scope, which sees
# neither the script's variables nor its ErrorActionPreference.
function Invoke-Action {
    param([hashtable] $a)
    $w = $a.With
    switch ($a.Kind) {
        'junction' {
            if (-not (Test-Path -LiteralPath $w.Parent)) {
                New-Item -ItemType Directory -Path $w.Parent -ErrorAction Stop | Out-Null
            }
            New-Item -ItemType Junction -Path $w.Link -Target $w.Source -ErrorAction Stop | Out-Null
        }
        # A junction is removed like an empty directory; what it points at is not touched.
        'unjunction' { [IO.Directory]::Delete($w.Link) }
        'rejunction' {
            [IO.Directory]::Delete($w.Link)
            New-Item -ItemType Junction -Path $w.Link -Target $w.Source -ErrorAction Stop | Out-Null
        }
        'env' {
            [Environment]::SetEnvironmentVariable($w.Name, $w.Value, $w.Scope)
            # This process too, so a tool run right after sees the new value.
            [Environment]::SetEnvironmentVariable($w.Name, $w.Value, 'Process')
        }
        'unsetenv' {
            [Environment]::SetEnvironmentVariable($w.Name, $null, $w.Scope)
            [Environment]::SetEnvironmentVariable($w.Name, $null, 'Process')
        }
        'write'  { [IO.File]::WriteAllText($w.Path, $w.Content) }
        'unlink' { Remove-Item -LiteralPath $w.Path -ErrorAction Stop }
        default  { throw "internal error: unknown action kind $($a.Kind)" }
    }
}
function Add-Conflict {
    param([string] $What, [string[]] $Hints)
    [void] $Conflicts.Add(@{ What = $What; Hints = $Hints })
}

function Plan-Junction {
    param([string] $PackageName, [string] $Rel)
    $source = Join-Path (Join-Path $Repo $PackageName) $Rel
    $link   = Join-Path $Target $Rel
    if (-not (Test-Path -LiteralPath $source -PathType Container)) {
        Fail "$source does not exist" 'the package changed layout; update the table in this script'
    }

    $existing = Get-Item -LiteralPath $link -Force -ErrorAction SilentlyContinue
    $ours = $false
    if ($existing -and (Test-ReparsePoint $existing)) {
        $ours = ((Get-LinkTarget $existing) -ieq $source.TrimEnd('\'))
    }

    if ($Remove) {
        if (-not $existing) { return }
        if ($ours) {
            Add-Action 'unjunction' "remove junction $link" @{ Link = $link }
        } else {
            Write-Hint "$link is not a junction into this repository, left alone"
        }
        return
    }

    if ($ours) { return }
    if ($existing) {
        if (Test-ReparsePoint $existing) {
            # A link into this repository whose target is gone is what a package
            # leaves behind when it moves; stow repairs those, so this does too.
            $was = Get-LinkTarget $existing
            if (($was -like "$Repo\*") -and -not (Test-Path -LiteralPath $was)) {
                Add-Action 'rejunction' "repair junction $link -> $source (pointed at $was, which is gone)" @{
                    Link = $link; Source = $source; Parent = (Split-Path -Parent $link) }
                return
            }
            # A symlink here is what stow-deploy-windows.sh makes, on a
            # machine that has the privilege for it: the other deploy of the
            # same package, not a stale link. Both write this path, so it is
            # let go of with the launcher that made it.
            if ($existing.LinkType -ieq 'SymbolicLink') {
                Add-Conflict "$link is a symlink to $was, which is how stow-deploy-windows.sh deploys $PackageName" @(
                    'that launcher needs Developer Mode or elevation, and is the one to prefer where it runs',
                    "to move to this script instead, undeploy it from git bash first:  stow --dir '$Repo' --target '$Target' -D $PackageName")
            } else {
                Add-Conflict "$link is a link to $was, not into this repository" @(
                    "remove it if it is stale:  Remove-Item -LiteralPath '$link'")
            }
        } elseif ($existing.PSIsContainer) {
            Add-Conflict "$link is a real directory" @(
                "move it aside:  Rename-Item -LiteralPath '$link' '$($existing.Name).pre-stow.bak'",
                'then run again; merge what it held by hand if any of it matters')
        } else {
            Add-Conflict "$link is a file, but a directory junction belongs there" @(
                "move it aside:  Rename-Item -LiteralPath '$link' '$($existing.Name).pre-stow.bak'")
        }
        return
    }

    Add-Action 'junction' "junction $link -> $source" @{
        Link = $link; Source = $source; Parent = (Split-Path -Parent $link) }
}

function Plan-Env {
    param([string] $Name, [string] $Value)
    $Value = Expand-Placeholders $Value
    if (-not $Remove -and $Value.StartsWith($Repo) -and -not (Test-Path -LiteralPath $Value)) {
        Fail "$Value does not exist" 'the package changed layout; update the table in this script'
    }
    $current = [Environment]::GetEnvironmentVariable($Name, $EnvScope)

    if ($Remove) {
        if ($null -eq $current) { return }
        if ($current -ine $Value) {
            Write-Hint "$Name is $current, not what this script sets, left alone"
            return
        }
        Add-Action 'unsetenv' "unset $Name ($EnvScope)" @{ Name = $Name; Scope = $EnvScope }
        return
    }

    if ($current -ieq $Value) { return }
    $verb = if ($null -eq $current) { 'set' } else { "change (was $current)" }
    Add-Action 'env' "$verb $Name=$Value ($EnvScope)" @{ Name = $Name; Value = $Value; Scope = $EnvScope }
}

function Plan-Include {
    param([string] $File, [string] $IncludePath)
    $IncludePath = (Expand-Placeholders $IncludePath)
    if (-not (Test-Path -LiteralPath $IncludePath -PathType Leaf)) {
        Fail "$IncludePath does not exist" 'the package changed layout; update the table in this script'
    }
    $stub = Join-Path $Target $File
    # git wants forward slashes, and reads them fine on Windows.
    $gitPath = $IncludePath.Replace('\', '/')
    $content = @(
        $StubMarker,
        '# the shared git config comes from the dotfiles repository. machine-local',
        '# settings belong in ~/.gitconfig.local, which that file includes.',
        '[include]',
        "`tpath = $gitPath"
    ) -join "`n"

    $existing = Get-Item -LiteralPath $stub -Force -ErrorAction SilentlyContinue
    $ours = $false
    if ($existing -and -not $existing.PSIsContainer -and -not (Test-ReparsePoint $existing)) {
        $ours = ((Get-Content -LiteralPath $stub -Raw -ErrorAction SilentlyContinue) -like "$StubMarker*")
    }

    if ($Remove) {
        if (-not $existing) { return }
        if ($ours) {
            Add-Action 'unlink' "remove $stub" @{ Path = $stub }
        } else {
            Write-Hint "$stub was not written by this script, left alone"
        }
        return
    }

    if ($ours) {
        $have = (Get-Content -LiteralPath $stub -Raw) -replace "`r`n", "`n"
        if ($have.TrimEnd("`n") -eq $content) { return }
        Add-Action 'write' "rewrite $stub (include $gitPath)" @{ Path = $stub; Content = $content + "`n" }
        return
    }
    if ($existing) {
        $what = if (Test-ReparsePoint $existing) { "a link to $(Get-LinkTarget $existing)" }
                elseif ($existing.PSIsContainer) { 'a directory' }
                else { 'a file this script did not write' }
        Add-Conflict "$stub is $what" @(
            'anything in it that is not in the repository belongs in ~/.gitconfig.local',
            "then move it aside:  Rename-Item -LiteralPath '$stub' '$File.pre-stow.bak'",
            "(a link is just removed:  Remove-Item -LiteralPath '$stub')")
        return
    }
    Add-Action 'write' "write $stub (include $gitPath)" @{ Path = $stub; Content = $content + "`n" }
}

foreach ($name in $Selected.Keys) {
    $spec = $Selected[$name]
    if ($spec.Contains('Junction')) {
        foreach ($rel in @($spec.Junction)) { Plan-Junction $name $rel }
    }
    if ($spec.Contains('Env')) {
        foreach ($k in $spec.Env.Keys) { Plan-Env $k $spec.Env[$k] }
    }
    if ($spec.Contains('Include')) { Plan-Include $spec.Include.File $spec.Include.Path }
}
if (-not $Remove -or $FullSet) {
    foreach ($k in $BaseEnv.Keys) { Plan-Env $k $BaseEnv[$k] }
}

# --- apply -----------------------------------------------------------------

if ($Conflicts.Count -gt 0) {
    foreach ($c in $Conflicts) {
        Write-Err $c.What
        foreach ($h in $c.Hints) { Write-Hint $h }
    }
    Fail "$($Conflicts.Count) conflict(s): nothing was deployed" `
        'clear them and run again; -n shows the plan without changing anything'
}

$verb = if ($Remove) { 'removed from' } else { 'deployed to' }
if ($Actions.Count -eq 0) {
    Write-Note "nothing to do: $($Selected.Count) package(s) already $verb $Target"
    exit 0
}

foreach ($a in $Actions) {
    Write-Step $a.Text
    if ($DryRun) { continue }
    try { Invoke-Action $a }
    catch { Fail "step failed: $($a.Text)" $_.Exception.Message 'the steps before it were applied; run again once the cause is fixed' }
}

if ($DryRun) {
    Write-Note "dry run, nothing changed: $($Actions.Count) step(s) for $($Selected.Count) package(s), $verb $Target"
} else {
    Write-Note "$($Selected.Count) package(s) $verb $Target"
    if ($RealProfile -and ($Actions | Where-Object { $_.Kind -eq 'env' -or $_.Kind -eq 'unsetenv' })) {
        Write-Note 'environment variables changed: they reach terminals opened from now on, not this one'
    }
    if (-not $Remove -and $Selected.Contains('herdr')) {
        Write-Note 'herdr layer 0 goes through nvim''s smart-splits checkout, which only nvim creates:'
        Write-Hint 'herdr plugin link "$env:LOCALAPPDATA\nvim-data\lazy\smart-splits.nvim"'
    }
    if (-not $Remove -and $Selected.Contains('nushell') -and (Get-Command nu -ErrorAction SilentlyContinue)) {
        Write-Note "nushell's starship and zoxide inits are generated: nu-regen-init.nu, see the shells section of the README"
    }
}
