# Performance tweaks for Windows
# Run from WSL via: powershell.exe -NoProfile -ExecutionPolicy Bypass -File <script>

function Set-RegistryValue {
    param(
        [string]$Path,
        [string]$Name,
        [object]$Value,
        [string]$Type = "DWord"
    )
    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -ErrorAction SilentlyContinue
}

Write-Host "Applying performance tweaks..."

# Disable Superfetch/SysMain (helps on SSD systems)
Stop-Service "SysMain" -ErrorAction SilentlyContinue
Set-Service "SysMain" -StartupType Disabled -ErrorAction SilentlyContinue

# Disable Windows Search indexing service (use Everything instead)
Stop-Service "WSearch" -ErrorAction SilentlyContinue
Set-Service "WSearch" -StartupType Disabled -ErrorAction SilentlyContinue

# Disable hibernation (saves disk space equal to RAM size)
& powercfg /h off 2>$null

# Set power plan to High Performance
$highPerf = powercfg /l | Select-String "High performance" | ForEach-Object {
    ($_ -split '\s+')[3]
}
if ($highPerf) {
    & powercfg /setactive $highPerf
    Write-Host "Set power plan to High Performance"
}

# Disable startup delay
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Serialize" "StartupDelayInMSec" 0

# Disable Game Bar and Game DVR
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" 0
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" "AllowGameDVR" 0
Set-RegistryValue "HKCU:\System\GameConfigStore" "GameDVR_Enabled" 0

# Reduce menu show delay
Set-RegistryValue "HKCU:\Control Panel\Desktop" "MenuShowDelay" "50" "String"

# Disable transparency effects (saves GPU resources)
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" "EnableTransparency" 0

# Disable animation effects for snappier UI
Set-RegistryValue "HKCU:\Control Panel\Desktop\WindowMetrics" "MinAnimate" "0" "String"

# Optimize NTFS for performance
Set-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "NtfsDisableLastAccessUpdate" 1

# Disable Remote Assistance
Set-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance" "fAllowToGetHelp" 0

Write-Host "Performance tweaks applied"
