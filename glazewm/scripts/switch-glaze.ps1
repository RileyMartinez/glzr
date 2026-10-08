<#
.SYNOPSIS
    GlazeWM profile switcher utility.

.DESCRIPTION
    Switches GlazeWM configurations between gaming, development, or any custom profiles.
    Hot-reloads GlazeWM, synchronizes PowerToys Keyboard Manager, and optionally launches apps.

.EXAMPLE
    switch-glaze
    Lists available and active profiles.

.EXAMPLE
    switch-glaze dev
    Switches to the dev profile, reloads GlazeWM, and enables Keyboard Manager.

.EXAMPLE
    switch-glaze gaming -LaunchApps
    Switches to gaming profile and starts any required apps not currently running.
#>

param(
    [Parameter(Position = 0)]
    [string]$Profile,

    [switch]$List,
    [switch]$LaunchApps,
    [switch]$NoKbmSync,
    [switch]$Help
)

$baseDir = "C:\Users\riley\.glzr\glazewm"
$profilesDir = Join-Path $baseDir "profiles"
$activeFile = Join-Path $baseDir "active_profile.txt"
$activeConfig = Join-Path $baseDir "config.yaml"
$scriptsDir = Join-Path $baseDir "scripts"
$toggleKbmScript = Join-Path $scriptsDir "toggle-kbm.ps1"

if ($Help) {
    Get-Help $MyInvocation.MyCommand.Path
    return
}

# Determine current active profile name
$currentActive = ""
if (Test-Path $activeFile) {
    $currentActive = (Get-Content -Raw $activeFile).Trim()
}

# Find all available profile files
$availableProfiles = @()
if (Test-Path $profilesDir) {
    $availableProfiles = Get-ChildItem -Path $profilesDir -Filter "*.yaml" | Select-Object -ExpandProperty BaseName
}

# If no profile specified or -List switch requested, display status table
if (-not $Profile -or $List) {
    Write-Host "`n=== GlazeWM Profile Manager ===" -ForegroundColor Cyan
    Write-Host "Profiles directory: $profilesDir" -ForegroundColor Gray

    if ($availableProfiles.Count -eq 0) {
        Write-Warning "No profiles found in $profilesDir!"
        return
    }

    Write-Host "`nAvailable Profiles:" -ForegroundColor Yellow
    foreach ($p in $availableProfiles) {
        if ($p -eq $currentActive) {
            Write-Host "  * $p  (ACTIVE)" -ForegroundColor Green
        } else {
            Write-Host "    $p" -ForegroundColor White
        }
    }

    Write-Host "`nUsage:" -ForegroundColor Cyan
    Write-Host "  glz <profile_name>              Switch profile and hot-reload"
    Write-Host "  glz <profile_name> -LaunchApps  Switch profile and launch missing apps"
    Write-Host "  toggle-kbm                      Toggle PowerToys Keyboard Manager (Caps Lock -> Ctrl)`n"
    return
}

# Clean profile name
$targetName = $Profile -replace '\.yaml$', ''
$targetFile = Join-Path $profilesDir "$targetName.yaml"

if (-not (Test-Path $targetFile)) {
    Write-Error "Profile '$targetName' not found! Available profiles: $($availableProfiles -join ', ')"
    return
}

Write-Host "Switching GlazeWM profile to '$targetName'..." -ForegroundColor Cyan

# 1. Copy config file
try {
    Copy-Item -Path $targetFile -Destination $activeConfig -Force
    Set-Content -Path $activeFile -Value $targetName -Encoding UTF8 -Force
    Write-Host " Config updated: $targetFile -> config.yaml" -ForegroundColor Green
} catch {
    Write-Error "Failed to update configuration: $_"
    return
}

# 2. Synchronize PowerToys Keyboard Manager state
if (-not $NoKbmSync -and (Test-Path $toggleKbmScript)) {
    if ($targetName -eq "dev") {
        Write-Host " Synchronizing PowerToys Keyboard Manager for Development..." -ForegroundColor Gray
        & pwsh -File $toggleKbmScript -Action on -Quiet
    } elseif ($targetName -eq "gaming") {
        Write-Host " Synchronizing PowerToys Keyboard Manager for Gaming..." -ForegroundColor Gray
        & pwsh -File $toggleKbmScript -Action off -Quiet
    }
}

# 3. Reload or start GlazeWM
$glazeProc = Get-Process -Name "glazewm" -ErrorAction SilentlyContinue
if ($glazeProc) {
    Write-Host " Reloading GlazeWM configuration..." -ForegroundColor Cyan
    try {
        & glazewm command wm-reload-config 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host " GlazeWM configuration hot-reloaded!" -ForegroundColor Green
        } else {
            Write-Warning "GlazeWM IPC is initializing or unavailable. The configuration file was updated."
        }
    } catch {
        Write-Warning "Could not reload GlazeWM via CLI: $_"
    }
} else {
    Write-Host "ℹ️ GlazeWM is not running. It will use '$targetName' when started." -ForegroundColor Yellow
}

# 4. Optional Application Launch Orchestration
if ($LaunchApps) {
    Write-Host "`nLaunching applications for profile '$targetName'..." -ForegroundColor Cyan

    $appMap = @{
        'gaming' = @(
            @{ Name = 'chrome'; Target = 'C:\Program Files\Google\Chrome\Application\chrome.exe'; Workspace = 1 },
            @{ Name = 'steam'; Target = 'C:\Program Files (x86)\Steam\steam.exe'; Workspace = 2 },
            @{ Name = '1Password'; Target = 'explorer.exe'; Args = 'shell:AppsFolder\Agilebits.1Password_amwd9z03whsfe!Agilebits.OnePassword'; Workspace = 5 },
            @{ Name = 'Obsidian'; Target = 'C:\Program Files\Obsidian\Obsidian.exe'; Workspace = 7 },
            @{ Name = 'WindowsTerminal'; Target = 'wt'; Workspace = 8 },
            @{ Name = 'Discord'; Target = "$env:LOCALAPPDATA\Discord\Discord.exe"; Workspace = 9 }
        )
        'dev' = @(
            @{ Name = 'chrome'; Target = 'C:\Program Files\Google\Chrome\Application\chrome.exe'; Workspace = 1 },
            @{ Name = 'Antigravity'; Target = "$env:LOCALAPPDATA\Programs\Antigravity\Antigravity.exe"; Workspace = 2 },
            @{ Name = 'Antigravity IDE'; Target = "$env:LOCALAPPDATA\Programs\Antigravity IDE\Antigravity IDE.exe"; Workspace = 3 },
            @{ Name = 'Docker Desktop'; Target = 'C:\Program Files\Docker\Docker\Docker Desktop.exe'; Workspace = 4 },
            @{ Name = '1Password'; Target = 'explorer.exe'; Args = 'shell:AppsFolder\Agilebits.1Password_amwd9z03whsfe!Agilebits.OnePassword'; Workspace = 5 },
            @{ Name = 'Obsidian'; Target = 'C:\Program Files\Obsidian\Obsidian.exe'; Workspace = 7 },
            @{ Name = 'WindowsTerminal'; Target = 'wt'; Workspace = 8 },
            @{ Name = 'Discord'; Target = "$env:LOCALAPPDATA\Discord\Discord.exe"; Workspace = 9 }
        )
    }

    if ($appMap.ContainsKey($targetName)) {
        foreach ($app in $appMap[$targetName]) {
            $isRunning = (Get-Process -Name $app.Name -ErrorAction SilentlyContinue) -ne $null
            if (-not $isRunning) {
                Write-Host "  Launching $($app.Name) (Workspace $($app.Workspace))..." -ForegroundColor White
                try {
                    if ($app.Args) {
                        Start-Process -FilePath $app.Target -ArgumentList $app.Args
                    } else {
                        Start-Process -FilePath $app.Target
                    }
                } catch {
                    Write-Warning "Failed to start $($app.Name): $_"
                }
            } else {
                Write-Host "  $($app.Name) is already running." -ForegroundColor Gray
            }
        }
    }
}

Write-Host "`n Active Profile: $targetName`n" -ForegroundColor Green
