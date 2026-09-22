#!/usr/bin/env pwsh
# A user-scope sshd on the Windows host, for `ssh win` from WSL -- see the
# README, windows. Installed, started and stopped by the account that owns it,
# with no admin rights: no Windows feature, no service, no firewall rule, no
# HKLM key.
#
#   windows-sshd-user.ps1 -Install   fetch OpenSSH-Win64.zip into
#                                    %LOCALAPPDATA%\Programs, make a host key
#                                    and an sshd_config under ~\.ssh\sshd
#   windows-sshd-user.ps1            start sshd hidden, bound to the WSL
#                                    adapter only (the default; what the
#                                    ProxyCommand runs before every connection)
#   windows-sshd-user.ps1 -Status    is it running, and on which address
#   windows-sshd-user.ps1 -Stop      kill it
#
# What "no admin" costs, and how each is paid for here:
#
#   the service. install-sshd.ps1 registers sshd as a SYSTEM service and needs
#   elevation, so this runs sshd.exe as the logged-on user, as a plain hidden
#   process. Win32-OpenSSH allows that with one limit: a non-SYSTEM sshd can
#   log in only the account it runs as, with a key -- which is all `ssh win`
#   wants. It dies with the session, so nothing autostarts it: the WSL side
#   starts it on demand, through windows-host-ssh-proxy.sh.
#
#   the port. 22 is privileged, 2222 is not.
#
#   the firewall. no rule can be added, and the default inbound action blocks
#   unsolicited traffic on every interface -- so sshd binds to the address of
#   the "vEthernet (WSL ...)" adapter alone and nothing on the LAN can reach it
#   even if the firewall let it. That adapter exists only while WSL runs, and
#   its address is fixed per Windows boot, so the start looks it up every time
#   and restarts an sshd left listening on a stale one. The connecting side
#   reaches the same address as its default gateway.
#
#   the shell. HKLM:\SOFTWARE\OpenSSH\DefaultShell picks the login shell and is
#   not writable, so a session lands in cmd.exe; run `ssh win pwsh` or set a
#   RemoteCommand on the client.
#
#   the keys. sshd running as SYSTEM reads administrators_authorized_keys for
#   admins; as a user it reads ~\.ssh\authorized_keys like anywhere else. Put
#   the WSL public key there by hand -- this script does not touch it.
#
# Windows PowerShell 5.1 is enough; the proxy calls it through powershell.exe.

[CmdletBinding()]
param(
    [switch] $Install,
    [switch] $Status,
    [switch] $Stop,
    [int]    $Port = 2222
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$prog     = 'windows-sshd-user'
$programs = Join-Path $env:LOCALAPPDATA 'Programs'
$bin      = Join-Path $programs 'OpenSSH-Win64'
$state    = Join-Path $env:USERPROFILE '.ssh\sshd'
$config   = Join-Path $state 'sshd_config'
$hostKey  = Join-Path $state 'ssh_host_ed25519_key'
$log      = Join-Path $state 'sshd.log'
$zipUrl   = 'https://github.com/PowerShell/Win32-OpenSSH/releases/latest/download/OpenSSH-Win64.zip'

function Say($msg) { Write-Host "${prog}: $msg" }
function Die($msg) { Write-Error "${prog}: $msg" -ErrorAction Continue; exit 1 }

function Wsl-Address {
    Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.InterfaceAlias -like 'vEthernet (WSL*' } |
        Select-Object -First 1 -ExpandProperty IPAddress
}

function Running { Get-Process -Name sshd -ErrorAction SilentlyContinue }

function Listening($address) {
    Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue |
        Where-Object { $_.LocalAddress -eq $address }
}

function Do-Install {
    if (Test-Path (Join-Path $bin 'sshd.exe')) {
        Say "openssh already in $bin"
    } else {
        $zip = Join-Path $env:TEMP 'OpenSSH-Win64.zip'
        Say "downloading $zipUrl"
        Invoke-WebRequest -Uri $zipUrl -OutFile $zip -UseBasicParsing
        New-Item -ItemType Directory -Force $programs | Out-Null
        Expand-Archive -Force $zip $programs
        Remove-Item $zip
        Say "unpacked into $bin"
    }
    New-Item -ItemType Directory -Force $state | Out-Null
    if (-not (Test-Path $hostKey)) {
        # -N '' through Start-Process: an empty argument survives, a '' on the
        # command line of & does not.
        $p = Start-Process -FilePath (Join-Path $bin 'ssh-keygen.exe') -NoNewWindow -Wait -PassThru `
            -ArgumentList @('-q', '-t', 'ed25519', '-N', '""', '-C', "sshd@$env:COMPUTERNAME", '-f', $hostKey)
        if ($p.ExitCode -ne 0) { Die "ssh-keygen failed ($($p.ExitCode))" }
        Say "host key $hostKey"
    }
    if (-not (Test-Path $config)) {
        @"
# user-scope sshd on $env:COMPUTERNAME, run as $env:USERNAME without admin rights
# by windows-sshd-user.ps1 (dotfiles), which also passes ListenAddress and Port.
HostKey $hostKey
LogLevel INFO
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitEmptyPasswords no
AllowUsers $env:USERNAME
Subsystem sftp sftp-server.exe
"@ | Set-Content -Encoding ASCII $config
        Say "config $config"
    }
    $authorized = Join-Path $env:USERPROFILE '.ssh\authorized_keys'
    if (-not (Test-Path $authorized) -or -not (Get-Content $authorized | Where-Object { $_ -match '^ssh-' })) {
        Say "no key in $authorized yet -- append the WSL ~/.ssh/id_ed25519.pub"
    }
    $p = Start-Process -FilePath (Join-Path $bin 'sshd.exe') -NoNewWindow -Wait -PassThru `
        -ArgumentList @('-t', '-f', $config)
    if ($p.ExitCode -ne 0) { Die "sshd -t rejects $config" }
    Say 'installed; start with windows-sshd-user.ps1, or just `ssh win` from WSL'
}

function Do-Status {
    $procs = @(Running)
    if (-not $procs) { Say 'not running'; exit 3 }
    $addr = Wsl-Address
    $bound = Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty LocalAddress
    Say ("running, pid " + ($procs.Id -join ',') + ", listening on " + ($bound -join ',') + `
         $(if ($addr -and ($bound -contains $addr)) { " (the WSL adapter)" } else { " -- WSL adapter is '$addr'" }))
}

function Do-Stop {
    $procs = @(Running)
    if (-not $procs) { Say 'not running'; return }
    $procs | Stop-Process -Force
    Say ("stopped pid " + ($procs.Id -join ','))
}

function Do-Start {
    if (-not (Test-Path (Join-Path $bin 'sshd.exe'))) { Die "not installed -- windows-sshd-user.ps1 -Install" }
    if (-not (Test-Path $config))  { Die "no $config -- windows-sshd-user.ps1 -Install" }
    $addr = Wsl-Address
    if (-not $addr) { Die 'no vEthernet (WSL) adapter -- WSL is not running, and sshd binds to nothing else' }
    if (Running) {
        if (Listening $addr) { return }
        Say "sshd is up but not on $addr (WSL adapter moved) -- restarting"
        Do-Stop
    }
    Start-Process -FilePath (Join-Path $bin 'sshd.exe') -WindowStyle Hidden `
        -ArgumentList @('-f', $config, '-E', $log, '-o', "ListenAddress=$addr", '-o', "Port=$Port")
    # give it a moment to bind, and report a failure here rather than as a
    # connection refused on the other side.
    foreach ($i in 1..20) {
        if (Listening $addr) { Say "listening on ${addr}:$Port"; return }
        Start-Sleep -Milliseconds 100
    }
    Die "sshd did not come up on ${addr}:$Port -- see $log"
}

if ($Install)     { Do-Install }
elseif ($Status)  { Do-Status }
elseif ($Stop)    { Do-Stop }
else              { Do-Start }
