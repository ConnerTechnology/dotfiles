# Common Windows settings and UI tweaks
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

Write-Host "Applying common Windows settings..."

$ExplorerPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"

# Show file extensions
Set-RegistryValue $ExplorerPath "HideFileExt" 0

# Show hidden files
Set-RegistryValue $ExplorerPath "Hidden" 1

# Show full path in Explorer title bar
Set-RegistryValue $ExplorerPath "FullPathAddress" 1

# Disable Snap Assist suggestions (the popup showing other windows to snap)
Set-RegistryValue $ExplorerPath "SnapAssist" 0

# Launch Explorer to "This PC" instead of "Quick Access"
Set-RegistryValue $ExplorerPath "LaunchTo" 1

# Disable recent files in Quick Access
Set-RegistryValue $ExplorerPath "ShowRecent" 0

# Disable frequent folders in Quick Access
Set-RegistryValue $ExplorerPath "ShowFrequent" 0

# Enable dark mode
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" "AppsUseLightTheme" 0
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" "SystemUsesLightTheme" 0

# Taskbar: Left-align taskbar (Windows 11)
Set-RegistryValue $ExplorerPath "TaskbarAl" 0

# Taskbar: Hide Search box (use Win key to search)
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" "SearchboxTaskbarMode" 0

# Taskbar: Hide Task View button
Set-RegistryValue $ExplorerPath "ShowTaskViewButton" 0

# Taskbar: Hide Widgets
Set-RegistryValue $ExplorerPath "TaskbarDa" 0

# Taskbar: Hide Chat (Teams)
Set-RegistryValue $ExplorerPath "TaskbarMn" 0

# Disable lock screen tips and ads
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "RotatingLockScreenEnabled" 0
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "RotatingLockScreenOverlayEnabled" 0

# Set default browser association prompt (don't nag about Edge)
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\UserProfileEngagement" "ScoobeSystemSettingEnabled" 0

# Disable "Show suggestions occasionally in Start"
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-338388Enabled" 0

# Set scroll lines to 5 (faster scrolling)
Set-RegistryValue "HKCU:\Control Panel\Desktop" "WheelScrollLines" "5" "String"

# Enable clipboard history
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Clipboard" "EnableClipboardHistory" 1

# Enable Developer Mode (useful for symlinks, etc.)
Set-RegistryValue "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" "AllowDevelopmentWithoutDevLicense" 1

Write-Host "Common Windows settings applied"
Write-Host "  - File extensions visible, hidden files shown"
Write-Host "  - Dark mode enabled"
Write-Host "  - Taskbar cleaned up (left-aligned, no widgets/chat/search)"
Write-Host "  - Explorer opens to This PC"
Write-Host "  - Developer Mode enabled"
