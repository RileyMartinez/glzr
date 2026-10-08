param(
    [ValidateSet('toggle', 'on', 'off')]
    [string]$Action = 'toggle',
    [switch]$Quiet
)

$settingsPath = "$env:LOCALAPPDATA\Microsoft\PowerToys\settings.json"
$ptExe = "C:\Program Files\PowerToys\PowerToys.exe"

# Determine current state from settings.json
$currentEnabled = $false
if (Test-Path $settingsPath) {
    try {
        $settingsContent = Get-Content -Raw $settingsPath | ConvertFrom-Json
        $currentEnabled = [bool]$settingsContent.enabled."Keyboard Manager"
    } catch {
        $currentEnabled = (Get-Process -Name "*KeyboardManager*" -ErrorAction SilentlyContinue) -ne $null
    }
}

# Determine target state
$targetEnabled = switch ($Action) {
    'on'     { $true }
    'off'    { $false }
    'toggle' { -not $currentEnabled }
}

# If state already matches and process matches, nothing to do
$procRunning = (Get-Process -Name "*KeyboardManagerEngine*" -ErrorAction SilentlyContinue) -ne $null
if ($currentEnabled -eq $targetEnabled -and $procRunning -eq $targetEnabled) {
    if (-not $Quiet) {
        if ($targetEnabled) {
            Write-Host "ℹ️ PowerToys Keyboard Manager is already ENABLED." -ForegroundColor Green
        } else {
            Write-Host "ℹ️ PowerToys Keyboard Manager is already DISABLED." -ForegroundColor Yellow
        }
    }
    return
}

# Update settings.json
if (Test-Path $settingsPath) {
    try {
        $settingsContent = Get-Content -Raw $settingsPath | ConvertFrom-Json
        $settingsContent.enabled."Keyboard Manager" = $targetEnabled
        $settingsContent | ConvertTo-Json -Depth 10 | Set-Content -Path $settingsPath -Encoding UTF8
    } catch {
        Write-Warning "Could not update PowerToys settings.json: $_"
    }
}

# Restart PowerToys to apply setting cleanly
Stop-Process -Name "PowerToys" -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 250
if (Test-Path $ptExe) {
    Start-Process -FilePath $ptExe -WindowStyle Hidden
}

# Provide audio cue
try {
    if ($targetEnabled) {
        [Console]::Beep(880, 150)
    } else {
        [Console]::Beep(440, 150)
    }
} catch {}

# Output terminal status
if (-not $Quiet) {
    if ($targetEnabled) {
        Write-Host "✅ PowerToys Keyboard Manager: ENABLED (Caps Lock -> Left Ctrl)" -ForegroundColor Green
    } else {
        Write-Host "❌ PowerToys Keyboard Manager: DISABLED (Caps Lock -> Normal)" -ForegroundColor Yellow
    }
}

# Show visual balloon tooltip for hotkey feedback
try {
    [reflection.assembly]::loadwithpartialname('System.Windows.Forms') | Out-Null
    $notify = New-Object System.Windows.Forms.NotifyIcon
    $notify.Icon = [System.Drawing.SystemIcons]::Information
    $notify.Visible = $true
    $title = "PowerToys Keyboard Manager"
    $msg = if ($targetEnabled) { "ENABLED (Caps Lock -> Left Ctrl)" } else { "DISABLED (Caps Lock -> Normal)" }
    $icon = if ($targetEnabled) { [System.Windows.Forms.ToolTipIcon]::Info } else { [System.Windows.Forms.ToolTipIcon]::Warning }
    $notify.ShowBalloonTip(1500, $title, $msg, $icon)
    Start-Sleep -Milliseconds 500
    $notify.Dispose()
} catch {}
