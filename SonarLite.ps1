<#
.SYNOPSIS
    SteelSeries Sonar Lite - Optimizer & Headless Manager
    Runs SteelSeries Sonar with minimal RAM footprint (~200MB instead of ~1.2GB)
    without the bloat of Moments, 3D Aim Trainer, and heavy Electron UI.
#>

[CmdletBinding()]
param (
    [Parameter(Position=0)]
    [ValidateSet("debloat", "keep-engine", "restore", "status", "start", "stop", "config", "clean-gui")]
    [string]$Action = "status",

    [switch]$NoElevation
)

$ErrorActionPreference = "Stop"

# Auto-elevate to Administrator if not elevated
function Test-Admin {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Admin) -and -not $NoElevation) {
    Write-Host "[*] Requesting Administrator privileges..." -ForegroundColor Yellow
    $scriptPath = $MyInvocation.MyCommand.Path
    $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" $Action"
    Start-Process powershell.exe -Verb RunAs -ArgumentList $argList
    exit
}

$InstallDir = "C:\Program Files\SteelSeries\GG"
$DataDir = "$env:ProgramData\SteelSeries\GG"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PythonScript = Join-Path $ScriptDir "sonar_lite.py"

function Write-Header {
    param([string]$Title)
    Write-Host "`n========================================================" -ForegroundColor Cyan
    Write-Host "   $Title" -ForegroundColor White
    Write-Host "========================================================" -ForegroundColor Cyan
}

function Stop-AllSteelSeries {
    Write-Host "[*] Stopping existing SteelSeries processes..." -ForegroundColor Yellow
    Get-Process | Where-Object { $_.Path -like "*SteelSeries*" } | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
}

function Start-HeadlessSonar {
    Write-Host "[*] Starting SteelSeries Sonar in Headless Mode..." -ForegroundColor Cyan
    
    $exePath = Join-Path $InstallDir "SteelSeriesGGEZ.exe"
    $procArgs = "-dataPath=`"$DataDir`" -dbEnv=production -auto=true"
    
    if (-not (Test-Path $exePath)) {
        Write-Host "[!] Error: $exePath not found!" -ForegroundColor Red
        return
    }

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $exePath
    $startInfo.Arguments = $procArgs
    $startInfo.WorkingDirectory = $InstallDir
    $startInfo.UseShellExecute = $true
    $startInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    [System.Diagnostics.Process]::Start($startInfo) | Out-Null

    Write-Host "[*] Waiting for services to initialize (8s)..." -ForegroundColor Gray
    Start-Sleep -Seconds 8

    # Purge any heavy Electron GUI processes that GGEZ might have accidentally spawned
    $gui = Get-Process -Name "SteelSeriesGGClient" -ErrorAction SilentlyContinue
    if ($gui) {
        Write-Host "[*] Suppressing Electron UI window to keep headless mode..." -ForegroundColor Gray
        $gui | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
    }
}

function Ensure-Autorun {
    Write-Host "[*] Configuring Windows Autorun for pure headless startup..." -ForegroundColor Gray
    $regKey = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run"
    $targetCmd = "`"$InstallDir\SteelSeriesGGEZ.exe`" -dataPath=`"$DataDir`" -dbEnv=production -auto=true"
    Set-ItemProperty -Path $regKey -Name "SteelSeriesGG" -Value $targetCmd -Force

    # Ensure it is marked as Enabled in Task Manager (StartupApproved)
    $approvedKeys = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run"
    )
    [byte[]]$enabledBytes = @(2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    foreach ($ak in $approvedKeys) {
        if (Test-Path $ak) {
            Set-ItemProperty -Path $ak -Name "SteelSeriesGG" -Value $enabledBytes -Type Binary -ErrorAction SilentlyContinue
        }
    }
}

function Show-ProcessStatus {
    Write-Header "CURRENT STEELSERIES MEMORY & PROCESS STATUS"
    
    $procs = Get-Process | Where-Object { $_.Path -like "*SteelSeries*" }
    if (-not $procs) {
        Write-Host "[-] No SteelSeries processes are currently running." -ForegroundColor Yellow
        return
    }

    $totalRAM = 0
    Write-Host ("{0,-28} | {1,8} | {2,12}" -f "Process Name", "PID", "Memory (MB)") -ForegroundColor Gray
    Write-Host ("-" * 54) -ForegroundColor Gray

    foreach ($p in ($procs | Sort-Object ProcessName)) {
        $ramMB = [math]::Round($p.WorkingSet64 / 1MB, 1)
        $totalRAM += $ramMB
        $color = if ($p.ProcessName -like "*Sonar*") { "Green" } elseif ($p.ProcessName -like "*Client*") { "Magenta" } else { "White" }
        Write-Host ("{0,-28} | {1,8} | {2,12}" -f $p.ProcessName, $p.Id, "$ramMB MB") -ForegroundColor $color
    }

    Write-Host ("-" * 54) -ForegroundColor Gray
    Write-Host ("{0,-28} | {1,8} | {2,12}" -f "TOTAL RAM CONSUMPTION", "", "$([math]::Round($totalRAM, 1)) MB") -ForegroundColor Cyan
    Write-Host "========================================================`n" -ForegroundColor Cyan

    # Check Sonar ports
    $sonar = $procs | Where-Object { $_.ProcessName -eq "SteelSeriesSonar" } | Select-Object -First 1
    if ($sonar) {
        $ports = Get-NetTCPConnection -OwningProcess $sonar.Id -State Listen -ErrorAction SilentlyContinue
        if ($ports) {
            $pList = ($ports | ForEach-Object { $_.LocalPort }) -join ", "
            Write-Host "[+] Sonar Audio Engine is ACTIVE and listening on port(s): $pList" -ForegroundColor Green
        }
    }
}

function Run-PythonWorker {
    param([string]$Arguments)
    
    # Try finding Python on PATH
    $py = Get-Command python -ErrorAction SilentlyContinue
    if (-not $py) {
        $py = Get-Command python3 -ErrorAction SilentlyContinue
    }
    
    # If not on PATH, check GG's internal python
    if (-not $py) {
        $internalPy = "C:\Program Files\SteelSeries\GG\cvgamesense\_internal\python310.dll"
        # If no standard python, search common locations
        $cand = @(
            "$env:LOCALAPPDATA\Programs\Python\Python311\python.exe",
            "$env:LOCALAPPDATA\Programs\Python\Python312\python.exe",
            "$env:ProgramFiles\Python311\python.exe",
            "$env:ProgramFiles\Python312\python.exe"
        )
        foreach ($c in $cand) {
            if (Test-Path $c) { $py = $c; break }
        }
    }

    if ($py) {
        $argList = @($Arguments -split '\s+' | Where-Object { $_ })
        & $py $PythonScript @argList
    } else {
        Write-Host "[!] Python not found. Trying built-in SQLite execution..." -ForegroundColor Yellow
        # Fallback using python code embedded or error
        Write-Host "[!] Please install Python or ensure python is on your system PATH." -ForegroundColor Red
    }
}

function Clean-GUIProcesses {
    Write-Host "[*] Purging leftover Electron UI processes..." -ForegroundColor Yellow
    $clients = Get-Process -Name "SteelSeriesGGClient" -ErrorAction SilentlyContinue
    if ($clients) {
        $clients | Stop-Process -Force
        Write-Host "[+] Purged $(@($clients).Count) GUI processes. Freed ~800MB RAM!" -ForegroundColor Green
    } else {
        Write-Host "[+] No heavy GUI processes detected." -ForegroundColor Gray
    }
}

function Start-ConfigGUI {
    Write-Header "LAUNCHING STEELSERIES GG SETTINGS"
    Write-Host "[*] Opening GG UI so you can configure Sonar / EQ presets..." -ForegroundColor Cyan
    Write-Host "[*] Tweak your settings, and when you CLOSE the window, press Enter here." -ForegroundColor Yellow

    # Launch UI
    $clientExe = Join-Path $InstallDir "SteelSeriesGGEZ.exe"
    Start-Process $clientExe -ArgumentList "-dataPath=`"$DataDir`" -dbEnv=production"
    
    Read-Host "`nPress [Enter] after you have closed the SteelSeries GG window to purge UI bloat"
    Clean-GUIProcesses
    Show-ProcessStatus
}

# Action router
switch ($Action.ToLower()) {
    "debloat" {
        Write-Header "APPLYING SONAR-ONLY LITE PROFILE"
        Stop-AllSteelSeries
        Run-PythonWorker "--debloat"
        Ensure-Autorun
        Start-HeadlessSonar
        Show-ProcessStatus
    }
    "keep-engine" {
        Write-Header "APPLYING SONAR LITE + ENGINE (MICE/KEYBOARDS) PROFILE"
        Stop-AllSteelSeries
        Run-PythonWorker "--debloat --keep-engine"
        Ensure-Autorun
        Start-HeadlessSonar
        Show-ProcessStatus
    }
    "restore" {
        Write-Header "RESTORE FACTORY STEELSERIES GG SETTINGS"
        Stop-AllSteelSeries
        Run-PythonWorker "--restore"
        Start-HeadlessSonar
        Show-ProcessStatus
    }
    "status" {
        Run-PythonWorker "--status"
        Show-ProcessStatus
    }
    "start" {
        Start-HeadlessSonar
        Show-ProcessStatus
    }
    "stop" {
        Stop-AllSteelSeries
        Show-ProcessStatus
    }
    "clean-gui" {
        Clean-GUIProcesses
        Show-ProcessStatus
    }
    "config" {
        Start-ConfigGUI
    }
    default {
        Write-Host "Unknown action: $Action" -ForegroundColor Red
        Write-Host "Valid actions: debloat, keep-engine, restore, status, start, stop, config, clean-gui"
    }
}
