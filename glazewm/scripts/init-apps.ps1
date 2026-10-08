<#
.SYNOPSIS
    Idempotent app initializer and window repinning engine for GlazeWM.

.DESCRIPTION
    Ensures that when GlazeWM starts up or reloads:
    1. Zebar is running.
    2. Required applications for the active profile (gaming or dev) are launched if and only if
       not already running (preventing duplicate instances).
    3. All existing and newly launched application windows are repinned / focused to their
       designated workspaces (1 through 9).
    4. Focus is restored to workspace 1.
#>

param(
    [Parameter(Position = 0)]
    [string]$Profile,

    [switch]$RepinOnly,
    [switch]$LaunchMissing,
    [switch]$VerboseOutput
)

$baseDir = "C:\Users\riley\.glzr\glazewm"
$activeFile = Join-Path $baseDir "active_profile.txt"

# 1. Determine target profile
if (-not $Profile) {
    if (Test-Path $activeFile) {
        $Profile = (Get-Content -Raw $activeFile).Trim()
    } else {
        $Profile = "gaming"
    }
}
$Profile = $Profile.ToLower()

# 2. Application and workspace mappings loaded from external apps.json
$appsFile = Join-Path $baseDir "apps.json"
if (-not (Test-Path $appsFile)) {
    Write-Error "Application configuration file '$appsFile' not found!"
    return
}

$rawJson = Get-Content -Raw $appsFile | ConvertFrom-Json
$appMatrix = @{}
foreach ($prop in $rawJson.PSObject.Properties) {
    $profKey = $prop.Name.ToLower()
    $appMatrix[$profKey] = @()
    foreach ($entry in $prop.Value) {
        $appMatrix[$profKey] += @{
            Name = $entry.name
            ProcessNames = @($entry.processNames)
            Target = [System.Environment]::ExpandEnvironmentVariables($entry.target)
            Args = if ($entry.args) { [System.Environment]::ExpandEnvironmentVariables($entry.args) } else { $null }
            Workspace = [string]$entry.workspace
            ForceTiling = [bool]$entry.forceTiling
        }
    }
}

if (-not $appMatrix.ContainsKey($Profile)) {
    Write-Warning "Profile '$Profile' not found in app matrix; defaulting to gaming."
    $Profile = 'gaming'
}

$apps = $appMatrix[$Profile]

# 3. Ensure Zebar is running
if (-not (Get-Process -Name "zebar" -ErrorAction SilentlyContinue)) {
    if ($VerboseOutput) { Write-Host "Starting Zebar..." -ForegroundColor Cyan }
    try {
        Start-Process "zebar" -ErrorAction SilentlyContinue
    } catch {}
}

# 4. Idempotent app launching (only if -RepinOnly is NOT set)
$launchedAny = $false
if (-not $RepinOnly) {
    foreach ($app in $apps) {
        $isRunning = $false
        foreach ($pName in $app.ProcessNames) {
            if (Get-Process -Name $pName -ErrorAction SilentlyContinue) {
                $isRunning = $true
                break
            }
        }

        if (-not $isRunning) {
            $launchedAny = $true
            if ($VerboseOutput) {
                Write-Host "Launching missing app: $($app.Name) (Workspace $($app.Workspace))..." -ForegroundColor Yellow
            }
            try {
                if ($app.Args) {
                    Start-Process -FilePath $app.Target -ArgumentList $app.Args -ErrorAction SilentlyContinue
                } else {
                    Start-Process -FilePath $app.Target -ErrorAction SilentlyContinue
                }
            } catch {
                if ($VerboseOutput) { Write-Warning "Failed to start $($app.Name): $_" }
            }
        } else {
            if ($VerboseOutput) {
                Write-Host "App already running: $($app.Name)" -ForegroundColor Gray
            }
        }
    }
}

# 5. Window Repinning Function
function Repin-Windows {
    param($Rules)

    $retry = 0
    $workspacesData = $null
    $windowsData = $null

    while ($retry -lt 15) {
        try {
            $wsRaw = & glazewm query workspaces 2>$null
            $winRaw = & glazewm query windows 2>$null
            if ($wsRaw -and $winRaw) {
                $wsObj = $wsRaw | ConvertFrom-Json
                $winObj = $winRaw | ConvertFrom-Json
                if ($wsObj.success -and $winObj.success) {
                    $workspacesData = $wsObj.data.workspaces
                    $windowsData = $winObj.data.windows
                    break
                }
            }
        } catch {}
        Start-Sleep -Milliseconds 150
        $retry++
    }

    if (-not $workspacesData -or -not $windowsData) {
        if ($VerboseOutput) { Write-Warning "Could not communicate with GlazeWM IPC." }
        return
    }

    # Map workspace name -> workspace ID
    $wsMap = @{}
    foreach ($ws in $workspacesData) {
        $wsMap[$ws.name] = $ws.id
    }

    foreach ($win in $windowsData) {
        # Find matching app rule by processName
        $matchedRule = $null
        foreach ($rule in $Rules) {
            if ($rule.ProcessNames -contains $win.processName) {
                $matchedRule = $rule
                break
            }
        }

        if ($matchedRule) {
            $targetWs = [string]$matchedRule.Workspace
            $targetWsId = $wsMap[$targetWs]
            if ($targetWsId -and $win.parentId -ne $targetWsId) {
                if ($VerboseOutput) {
                    Write-Host "Repinning $($win.processName) (window $($win.id)) -> Workspace $targetWs" -ForegroundColor Green
                }
                if ($matchedRule.ForceTiling) {
                    & glazewm command --id $win.id set-tiling 2>$null | Out-Null
                }
                & glazewm command --id $win.id move --workspace $targetWs 2>$null | Out-Null
            }
        }
    }
}

# 6. Execute window repinning
# Immediate pass for all existing windows
Repin-Windows -Rules $apps

# If newly launched apps are still initializing windows, perform a second pass
if ($launchedAny) {
    Start-Sleep -Milliseconds 1500
    Repin-Windows -Rules $apps
}

# 7. Restore focus to workspace 1
& glazewm command focus --workspace 1 2>$null | Out-Null
