# Remove Windows bloatware apps
# Run from WSL via: powershell.exe -NoProfile -ExecutionPolicy Bypass -File <script>

# List of bloatware app packages to remove
$BloatwareApps = @(
    "Microsoft.3DBuilder"
    "Microsoft.BingFinance"
    "Microsoft.BingNews"
    "Microsoft.BingSports"
    "Microsoft.BingWeather"
    "Microsoft.GamingApp"
    "Microsoft.GetHelp"
    "Microsoft.Getstarted"
    "Microsoft.MicrosoftOfficeHub"
    "Microsoft.MicrosoftSolitaireCollection"
    "Microsoft.MixedReality.Portal"
    "Microsoft.People"
    "Microsoft.PowerAutomateDesktop"
    "Microsoft.SkypeApp"
    "Microsoft.Todos"
    "Microsoft.WindowsAlarms"
    "Microsoft.WindowsFeedbackHub"
    "Microsoft.WindowsMaps"
    "Microsoft.Xbox.TCUI"
    "Microsoft.XboxApp"
    "Microsoft.XboxGameOverlay"
    "Microsoft.XboxGamingOverlay"
    "Microsoft.XboxIdentityProvider"
    "Microsoft.XboxSpeechToTextOverlay"
    "Microsoft.YourPhone"
    "Microsoft.ZuneMusic"
    "Microsoft.ZuneVideo"
    "Clipchamp.Clipchamp"
    "Microsoft.549981C3F5F10"  # Cortana
    "MicrosoftTeams"
    "Microsoft.OutlookForWindows"
    "Microsoft.WindowsCommunicationsApps"  # Mail and Calendar
)

foreach ($app in $BloatwareApps) {
    $package = Get-AppxPackage -Name $app -ErrorAction SilentlyContinue
    if ($package) {
        Write-Host "Removing $app..."
        $package | Remove-AppxPackage -ErrorAction SilentlyContinue
    }

    # Also remove provisioned packages to prevent reinstall for new users
    $provisioned = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -eq $app }
    if ($provisioned) {
        $provisioned | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
    }
}

Write-Host "Bloatware removal complete"
