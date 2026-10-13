# The PowerShell 7 profile of the windows machine. stow-deploy-windows.sh links
# it into ~\Documents\PowerShell; deploy-windows-noadmin.ps1 writes a stub there
# that dot-sources it from the checkout. Either way $PSScriptRoot is a directory
# that holds fzf.ps1 as well. Not deployed on linux, see stow-deploy.sh.

# Import-Module C:\SWProjekte\tools\tools\z\z.psd1

Set-PSReadLineOption -PredictionViewStyle ListView

Set-Alias -Name e -Value explorer
Set-Alias -Name g -Value git
Set-Alias -Name c -Value code
Set-Alias -Name cl ~/.local/bin/claude.exe
# clc is PowerShell's own alias for Clear-Content, and an alias wins over a
# function of the same name -- so it has to go, or `clc` empties files.
Remove-Item Alias:clc -Force -ErrorAction SilentlyContinue
function clc { cl --continue @args }
function clr { cl --resume @args }

# Functions rather than aliases, because Set-Alias cannot carry an argument
# like `build`; @args passes the rest on, so `dnr --project foo` works as in
# fish. One catch: PowerShell swallows the first bare `--` on the way into a
# function, so arguments for the program itself need it twice or quoted:
# `dnr -- -- --urls x` or `dnr '--' --urls x`.
Set-Alias -Name dn -Value dotnet
function dnb { dotnet build @args }
function dnr { dotnet run @args }
function dnt { dotnet test @args }
function dnpa { dotnet package add @args }
Set-Alias -Name dnap -Value dnpa
function dnn { dotnet new @args }
function dnsa { dotnet sln add @args }
function dnpub { dotnet publish @args }
function dnto { dotnet tool @args }

$swprojekte = "C:\SWProjekte"

. "$PSScriptRoot\fzf.ps1"

Invoke-Expression (&starship init powershell)

Invoke-Expression (& { (zoxide init powershell | Out-String) })

$prompt__ = (get-item "function:prompt").ScriptBlock
function prompt() { 
    $Host.UI.RawUI.WindowTitle = (Get-Item (Get-Location)).Name; 
    return $prompt__.Invoke() 
}

function claude {
    $exe = get-item 'C:\Users\Gawlik.MiGa\.vscode\extensions\anthropic.claude-code-*\resources\native-binary\claude.exe' | 
      sort-object -Descending -Property VersionInfo | 
      select-object -First 1

    if ($null -eq $exe) {
        Write-Error "claude.exe nicht gefunden"
    }
    &"$exe" $args
}

function sm {
    fd -t f -e '.lnk' --search-path 'C:\ProgramData\Microsoft\Windows\Start Menu' | fzf | % { &"$_" }
}

function gwl { 
    Push-Location 'c:/GitRepositories/FirstX'; 
    $wl = git wl; 
    Pop-Location; 
    $wl;
}

function gz($searchText) { 
    if ($null -ne $searchText) {
      $match = gwl | fzf -f $searchText 
    } else {
      $match = gwl | fzf --preview 'git --git-dir {1}/.git lg --color=always' 
    }
    if ($null -ne $match){
      Set-Location $match.split(" ")[0];
    }
}

function gb() {
  git branch --format '%(refname:short)' | 
    Sort-Object | 
    fzf --preview 'git lg --oneline origin/master..{} --color=always' 
}

function gsw(){
    gb | ForEach-Object{ git switch $_ }
}

function gsw() {
    $branch = gb
    if (-not $branch) { return }

    $lines = git worktree list --porcelain
    $worktreePath = $null
    $currentPath = $null

    foreach ($line in $lines) {
        if ($line -match '^worktree (.+)') {
            $currentPath = $Matches[1]
        } elseif ($line -eq "branch refs/heads/$branch") {
            $worktreePath = $currentPath
            break
        }
    }

    if ($worktreePath) {
        Set-Location $worktreePath
    } else {
        git switch $branch
    }
}

function Find-TopFiles {
    param(
        [Parameter(Mandatory)][string]$Pattern,
        [int]$Top = 0,
        [string]$Path = ".",
        [switch]$Multiline
    )
    $rgArgs = @('-c', $Pattern, $Path)
    if ($Multiline) { $rgArgs = @('-c', '--multiline', $Pattern, $Path) }
    $results = rg @rgArgs 2>$null |
    ForEach-Object { $file, $count = $_ -split ':', 2; [PSCustomObject]@{ File = $file; Count = [int]$count } } |
    Sort-Object Count -Descending
    if ($Top -gt 0) { $results | Select-Object -First $Top } else { $results }
}

function cdp ($path) { set-location "$path/.." }

function fdp { fd -e .vbproj -e .csproj -e .fsproj -t f | sort | fzf --preview 'bat -l XML {} --color always' | % { &"$_" } }

function fds([string]$searchText) {
    $files = fd -e slnf -u -t f | Sort-Object
    if ([string]::IsNullOrWhiteSpace($searchText)) {
        $files | fzf --preview 'bat -l json {} --color always'
    }
    else {
        $files | fzf -f $searchText | Select-Object -First 1
    }
}

function fo { param($code) explorer "fo:$code" }

function lz { eza --color=always --icons=always --long --group-directories-first -A $args }

function git-filehistory { 
    param([string]$path) 

    if ([string]::IsNullOrWhiteSpace($path)) {
        $path = (fd --type file | Sort-Object | fzf --preview "bat $((get-item .).fullname)/{} --color always");
    }

    $log = git log  --graph --color=always --abbrev-commit --decorate --format="%C(auto)%h %C(green)(%an)%C(auto)%d %s %C(black)%C(bold)%cr "  -- $path;

    $log | fzf --ansi --no-sort --reverse --tiebreak=index --preview "git show --ignore-all-space {2} -- $($path.replace('\', '/')) | delta" --preview-window=up:60% 
}

function git-diff2 {
    param([parameter(Mandatory = $False)][string]$target = "origin/master")
    git diff --name-only (git branch --show-current) (git merge-base (git branch --show-current) $target)
}

function git-branches() {
    $firstXFolders = Get-ChildItem -Path $swprojekte -Directory -Filter "firstx-*"
    $firstXFolders | ForEach-Object {
        $folder = $_
        Write-Host $folder -ForegroundColor Green
        Push-Location $folder
        git branch --show-current "$folder"
        Pop-Location
        Write-Host ""
    }
}

function git-unstaged() {
    git status --short | sls "^.\S\s+(.+)" | % { $_.Matches.Groups[1].Value }
}

function git-push-set-upstream-origin {
    $BranchName = git branch --show-current
    Write-Host "Remote Branch: '$BranchName' Ok?"; 
    Read-Host > $null; 
    git push --set-upstream origin $BranchName;
}

function git-diff-with-merge-base {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$targetBranch = "origin/master",

        [Parameter(Mandatory = $false)]
        [switch]$nameOnly
    )

    $currentBranch = git branch --show-current
    $MergeBase = git merge-base $currentBranch $targetBranch

    if ($nameOnly) {
        git diff --name-only $BranchName $MergeBase
    }
    else {
        git diff $target $BranchName $MergeBase
    }
}

function gitlab-open {
    $BranchName = git branch --show-current
    Start-Process msedge "https://gitlab.klafka-hinz.de/KH/firstx/-/merge_requests?scope=all&state=opened&source_branch=$BranchName"
}