[CmdletBinding()]
param (
    [Parameter(mandatory=$false)][string]$exePath = "C:\bin\kmonad.exe",
    [Parameter(mandatory=$false)][string]$configPath = "~/.config/kmonad/homerowmod.kdb",
    [Parameter(mandatory=$false)][string]$taskName = "KMonad HomerowMod",
    [Parameter(mandatory=$false)][string]$taskDescription = "Run kmonad.exe with homerowmod.kdb on user logon"
)   
$configFile = (get-item $configPath)
$exeFile = (get-item $exePath)

if (-not $exeFile) {
    Write-Error "$exePath does not exist. Please provide a valid path to kmonad.exe."
    return
}
if (-not $configFile) {
    Write-Error "$configPath does not exist. Please provide a valid path to the kmonad configuration file."
    return
}

$action = New-ScheduledTaskAction -Execute $exeFile.Fullname -Argument $configFile.Fullname
$trigger = New-ScheduledTaskTrigger -AtLogOn
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERNAME" -LogonType Interactive -RunLevel Highest

Register-ScheduledTask -TaskName $taskName `
                       -Action $action `
                       -Trigger $trigger `
                       -Principal $principal `
                       -Description $taskDescription

