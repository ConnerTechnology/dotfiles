# Windows Update settings
# Run from WSL via: powershell.exe -NoProfile -ExecutionPolicy Bypass -File <script>
#
# These settings defer feature and quality updates to avoid being a beta tester.
# Updates still install automatically, just with a delay for stability.

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

Write-Host "Configuring Windows Update settings..."

$WUPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
$AUPath = "$WUPath\AU"

# Defer feature updates by 30 days (let others find the bugs first)
Set-RegistryValue $WUPath "DeferFeatureUpdates" 1
Set-RegistryValue $WUPath "DeferFeatureUpdatesPeriodInDays" 30

# Defer quality updates by 7 days
Set-RegistryValue $WUPath "DeferQualityUpdates" 1
Set-RegistryValue $WUPath "DeferQualityUpdatesPeriodInDays" 7

# Notify before downloading and installing updates (don't auto-restart)
# 2 = Notify for download and auto install
# 3 = Auto download and notify for install
# 4 = Auto download and schedule install
Set-RegistryValue $AUPath "AUOptions" 3
Set-RegistryValue $AUPath "NoAutoRebootWithLoggedOnUsers" 1

# Set active hours to prevent surprise restarts (8 AM to 11 PM)
Set-RegistryValue $WUPath "SetActiveHours" 1
Set-RegistryValue $WUPath "ActiveHoursStart" 8
Set-RegistryValue $WUPath "ActiveHoursEnd" 23

# Disable driver updates via Windows Update (manage drivers manually)
Set-RegistryValue "$WUPath" "ExcludeWUDriversInQualityUpdate" 1

# Disable auto-restart when users are logged on
Set-RegistryValue $AUPath "NoAutoRebootWithLoggedOnUsers" 1

Write-Host "Windows Update settings configured"
Write-Host "  - Feature updates deferred by 30 days"
Write-Host "  - Quality updates deferred by 7 days"
Write-Host "  - Active hours: 8 AM - 11 PM"
Write-Host "  - Auto-restart disabled when logged in"
