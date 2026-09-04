# ==============================================================================
#  WinRE System Diagnostic & Repair Tool (PowerShell 7)
# ==============================================================================

# Ensure ANSI colors are supported
$Host.UI.RawUI.ForegroundColor = "White"

# Auto-detect target Windows OS installation drive in WinRE
function Get-TargetWindowsDrive {
    $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Free -ne $null }
    foreach ($drive in $drives) {
        $winPath = Join-Path "$($drive.Name):\" "Windows\System32\kernel32.dll"
        if (Test-Path $winPath) {
            return "$($drive.Name):\"
        }
    }
    return $null
}

$Global:TargetDrive = Get-TargetWindowsDrive
$Global:TargetWinDir = if ($Global:TargetDrive) { Join-Path $Global:TargetDrive "Windows" } else { $null }

# ------------------------------------------------------------------------------
# UI Helper Functions
# ------------------------------------------------------------------------------
function Draw-Header {
    Clear-Host
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "                        WinRE System Diagnostic Center                          " -ForegroundColor Cyan
    if ($Global:TargetDrive) {
        Write-Host "                Target OS Detected: $Global:TargetWinDir" -ForegroundColor DarkYellow
    } else {
        Write-Host "                [!] WARNING: Windows OS Drive Not Found!" -ForegroundColor Red
    }
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host ""
}

function Draw-Divider {
    Write-Host ""
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray
}

# ------------------------------------------------------------------------------
# Diagnostic Scans
# ------------------------------------------------------------------------------
function Scan-CoreFiles {
    Write-Host "`n[+] Checking Critical System Files & DLLs..." -ForegroundColor Cyan
    if (-not $Global:TargetWinDir) { Write-Host "[-] OS Drive missing." -ForegroundColor Red; return }
    
    $criticalFiles = @(
        "System32\kernel32.dll",
        "System32\ntdll.dll",
        "System32\user32.dll",
        "System32\hal.dll",
        "System32\winlogon.exe",
        "System32\drivers\etc\hosts"
    )

    foreach ($file in $criticalFiles) {
        $fullPath = Join-Path $Global:TargetWinDir $file
        if (Test-Path $fullPath) {
            Write-Host "  [OK] Found: $file" -ForegroundColor Green
        } else {
            Write-Host "  [MISSING] $file" -ForegroundColor Red
        }
    }
}

function Scan-Directories {
    Write-Host "`n[+] Checking Critical Windows Directories..." -ForegroundColor Cyan
    if (-not $Global:TargetWinDir) { Write-Host "[-] OS Drive missing." -ForegroundColor Red; return }

    $criticalDirs = @(
        "System32",
        "SysWOW64",
        "WinSxS",
        "System32\drivers",
        "System32\config"
    )

    foreach ($dir in $criticalDirs) {
        $fullPath = Join-Path $Global:TargetWinDir $dir
        if (Test-Path $fullPath) {
            Write-Host "  [OK] Found: $dir" -ForegroundColor Green
        } else {
            Write-Host "  [MISSING] $dir" -ForegroundColor Red
        }
    }
}

function Scan-OfflineServices {
    Write-Host "`n[+] Checking Core Offline Windows Services Registry..." -ForegroundColor Cyan
    if (-not $Global:TargetWinDir) { Write-Host "[-] OS Drive missing." -ForegroundColor Red; return }

    $hivePath = Join-Path $Global:TargetWinDir "System32\config\SYSTEM"
    if (-not (Test-Path $hivePath)) {
        Write-Host "  [ERROR] SYSTEM hive not found at $hivePath" -ForegroundColor Red
        return
    }

    # Load Offline Registry Hive
    reg load "HKLM\OFFLINE_SYS" $hivePath | Out-Null
    
    $servicesToCheck = @("RpcSs", "DcomLaunch", "EventLog", "Winmgmt", "TrustedInstaller")
    foreach ($svc in $servicesToCheck) {
        $svcKey = "HKLM:\OFFLINE_SYS\ControlSet001\Services\$svc"
        if (Test-Path $svcKey) {
            Write-Host "  [OK] Offline Service Registered: $svc" -ForegroundColor Green
        } else {
            Write-Host "  [MISSING] Service Registry Key: $svc" -ForegroundColor Red
        }
    }

    # Unload Registry Hive
    [GC]::Collect()
    reg unload "HKLM\OFFLINE_SYS" | Out-Null
}

function Scan-ComponentStoreHealth {
    Write-Host "`n[+] Checking DISM Component Store Health..." -ForegroundColor Cyan
    if (-not $Global:TargetDrive) { Write-Host "[-] OS Drive missing." -ForegroundColor Red; return }

    dism.exe /Image:$Global:TargetDrive /Cleanup-Image /CheckHealth
}

# ------------------------------------------------------------------------------
# Repair Operations
# ------------------------------------------------------------------------------
function Repair-SFC {
    Write-Host "`n[+] Executing Offline System File Checker (SFC)..." -ForegroundColor Yellow
    if (-not $Global:TargetDrive) { Write-Host "[-] OS Drive missing." -ForegroundColor Red; return }

    sfc.exe /scannow /offbootdir=$Global:TargetDrive /offwindir=$Global:TargetWinDir
}

function Repair-DISM {
    Write-Host "`n[+] Executing Offline DISM RestoreHealth..." -ForegroundColor Yellow
    if (-not $Global:TargetDrive) { Write-Host "[-] OS Drive missing." -ForegroundColor Red; return }

    dism.exe /Image:$Global:TargetDrive /Cleanup-Image /RestoreHealth
}

function Repair-Directories {
    Write-Host "`n[+] Rebuilding Missing Standard Folders..." -ForegroundColor Yellow
    if (-not $Global:TargetWinDir) { Write-Host "[-] OS Drive missing." -ForegroundColor Red; return }

    $dirsToEnsure = @("System32\drivers", "SysWOW64", "Logs")
    foreach ($dir in $dirsToEnsure) {
        $fullPath = Join-Path $Global:TargetWinDir $dir
        if (-not (Test-Path $fullPath)) {
            New-Item -Path $fullPath -ItemType Directory -Force | Out-Null
            Write-Host "  [REPAIRED] Created folder: $dir" -ForegroundColor Green
        }
    }
}

# ------------------------------------------------------------------------------
# Menu Handlers
# ------------------------------------------------------------------------------
function Menu-ScanAllAndRepair {
    Draw-Header
    Write-Host "Running FULL System Diagnostics & Auto-Repair..." -ForegroundColor Yellow
    
    Scan-Directories
    Scan-CoreFiles
    Scan-OfflineServices
    Scan-ComponentStoreHealth
    
    Draw-Divider
    Write-Host "Initiating Automated Repairs..." -ForegroundColor Yellow
    Repair-Directories
    Repair-SFC
    Repair-DISM

    Write-Host "`n[+] All tasks complete." -ForegroundColor Green
    Pause
}

function Menu-CustomScans {
    Draw-Header
    Write-Host "Select Diagnostics to Run:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "   [" -NoNewline; Write-Host "1" -ForegroundColor Green -NoNewline; Write-Host "] Core Files & System DLLs Scan"
    Write-Host "   [" -NoNewline; Write-Host "2" -ForegroundColor Green -NoNewline; Write-Host "] Directory Structure Scan"
    Write-Host "   [" -NoNewline; Write-Host "3" -ForegroundColor Green -NoNewline; Write-Host "] Offline Windows Services Check"
    Write-Host "   [" -NoNewline; Write-Host "4" -ForegroundColor Green -NoNewline; Write-Host "] DISM Component Store Check"
    Write-Host "   [" -NoNewline; Write-Host "A" -ForegroundColor Green -NoNewline; Write-Host "] Run All Selected Scans"
    Draw-Divider

    $selection = Read-Host "Choose options (e.g. 1,2 or A)"
    Draw-Header

    if ($selection -match "1" -or $selection -eq "A") { Scan-CoreFiles }
    if ($selection -match "2" -or $selection -eq "A") { Scan-Directories }
    if ($selection -match "3" -or $selection -eq "A") { Scan-OfflineServices }
    if ($selection -match "4" -or $selection -eq "A") { Scan-ComponentStoreHealth }

    Pause
}

function Menu-CustomRepairs {
    Draw-Header
    Write-Host "Select Repair Actions:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "   [" -NoNewline; Write-Host "1" -ForegroundColor Green -NoNewline; Write-Host "] Run Offline SFC /scannow"
    Write-Host "   [" -NoNewline; Write-Host "2" -ForegroundColor Green -NoNewline; Write-Host "] Run Offline DISM Component Store Repair"
    Write-Host "   [" -NoNewline; Write-Host "3" -ForegroundColor Green -NoNewline; Write-Host "] Restore Missing Essential System Directories"
    Draw-Divider

    $selection = Read-Host "Choose options to run (e.g. 1,3)"
    Draw-Header

    if ($selection -match "1") { Repair-SFC }
    if ($selection -match "2") { Repair-DISM }
    if ($selection -match "3") { Repair-Directories }

    Pause
}

# ------------------------------------------------------------------------------
# Main Application Loop
# ------------------------------------------------------------------------------
do {
    Draw-Header
    Write-Host "   Diagnostic Options:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "   [" -NoNewline; Write-Host "1" -ForegroundColor Green -NoNewline; Write-Host "] Scan All & Auto-Repair"
    Write-Host "   [" -NoNewline; Write-Host "2" -ForegroundColor Green -NoNewline; Write-Host "] Choose Scans to Run (Scan Only)"
    Write-Host "   [" -NoNewline; Write-Host "3" -ForegroundColor Green -NoNewline; Write-Host "] Choose What to Repair"
    Draw-Divider
    Write-Host "   [" -NoNewline; Write-Host "Q" -ForegroundColor Red -NoNewline; Write-Host "] Quit"
    Draw-Divider
    
    $choice = Read-Host "`nChoose option [1..3, Q]"

    switch ($choice.ToUpper()) {
        "1" { Menu-ScanAllAndRepair }
        "2" { Menu-CustomScans }
        "3" { Menu-CustomRepairs }
        "Q" { Clear-Host; break }
    }
} while ($true)
