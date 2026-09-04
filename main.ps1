$Host.UI.RawUI.ForegroundColor = "White"

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

if ($Global:TargetWinDir -and (Test-Path $Global:TargetWinDir)) {
    Set-Location -Path $Global:TargetWinDir
}

$Global:ScratchDir = if ($Global:TargetWinDir) {
    $tempScratch = Join-Path $Global:TargetWinDir "Temp\DISMScratch"
    if (-not (Test-Path $tempScratch)) { New-Item -Path $tempScratch -ItemType Directory -Force | Out-Null }
    $tempScratch
} else { $null }

function Draw-Header {
    Clear-Host
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "                        WinRE System Diagnostic Center                          " -ForegroundColor Cyan
    if ($Global:TargetDrive) {
        Write-Host "                Target OS Detected: $Global:TargetWinDir" -ForegroundColor DarkYellow
        Write-Host "                Working Directory:  $((Get-Location).Path)" -ForegroundColor DarkGray
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

function Wait-KeyPress {
    Write-Host "`nPress Enter to return to the menu..." -ForegroundColor DarkGray
    Read-Host | Out-Null
}

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

    [GC]::Collect()
    reg unload "HKLM\OFFLINE_SYS" | Out-Null
}

function Scan-ComponentStoreHealth {
    Write-Host "`n[+] Checking DISM Component Store Health [dism.exe /Image /Cleanup-Image /CheckHealth]..." -ForegroundColor Cyan
    if (-not $Global:TargetDrive) { Write-Host "[-] OS Drive missing." -ForegroundColor Red; return }

    if ($Global:ScratchDir) {
        dism.exe /Image:$Global:TargetDrive /ScratchDir:$Global:ScratchDir /Cleanup-Image /CheckHealth
    } else {
        dism.exe /Image:$Global:TargetDrive /Cleanup-Image /CheckHealth
    }
}

function Repair-SFC {
    Write-Host "`n[+] Running SFC Scan [sfc /scannow /offbootdir /offwindir]..." -ForegroundColor Yellow
    if (-not $Global:TargetDrive) { Write-Host "[-] OS Drive missing." -ForegroundColor Red; return }

    sfc.exe /scannow /offbootdir=$Global:TargetDrive /offwindir=$Global:TargetWinDir
}

function Repair-DISM {
    Write-Host "`n[+] Running DISM RestoreHealth [dism.exe /Image /Cleanup-Image /RestoreHealth]..." -ForegroundColor Yellow
    if (-not $Global:TargetDrive) { Write-Host "[-] OS Drive missing." -ForegroundColor Red; return }

    if ($Global:ScratchDir) {
        dism.exe /Image:$Global:TargetDrive /ScratchDir:$Global:ScratchDir /Cleanup-Image /RestoreHealth
    } else {
        dism.exe /Image:$Global:TargetDrive /Cleanup-Image /RestoreHealth
    }
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

function Repair-Chkdsk {
    Write-Host "`n[+] Running Disk Check [chkdsk /f /r /x]..." -ForegroundColor Yellow
    if (-not $Global:TargetDrive) { Write-Host "[-] OS Drive missing." -ForegroundColor Red; return }

    $driveLetter = $Global:TargetDrive.TrimEnd("\")
    
    cmd.exe /c "echo Y | chkdsk.exe $driveLetter /f /r /x"
}

function Repair-BootRec {
    Write-Host "`n[+] Executing Boot Sector & MBR Repair [bootrec]..." -ForegroundColor Yellow
    
    Write-Host "Running bootrec /fixmbr..." -ForegroundColor Cyan
    bootrec.exe /fixmbr
    
    Write-Host "Running bootrec /fixboot..." -ForegroundColor Cyan
    bootrec.exe /fixboot
    
    Write-Host "Running bootrec /rebuildbcd..." -ForegroundColor Cyan

    cmd.exe /c "echo A | bootrec.exe /rebuildbcd"
}

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
    Repair-Chkdsk
    Repair-SFC
    Repair-DISM
    Repair-BootRec

    Write-Host "`n[+] All tasks complete." -ForegroundColor Green
    Wait-KeyPress
}

function Menu-CustomScans {
    Draw-Header
    Write-Host "Select Diagnostics to Run:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "   [" -NoNewline; Write-Host "1" -ForegroundColor Green -NoNewline; Write-Host "] Core Files & System DLLs Scan"
    Write-Host "   [" -NoNewline; Write-Host "2" -ForegroundColor Green -NoNewline; Write-Host "] Directory Structure Scan"
    Write-Host "   [" -NoNewline; Write-Host "3" -ForegroundColor Green -NoNewline; Write-Host "] Offline Windows Services Check"
    Write-Host "   [" -NoNewline; Write-Host "4" -ForegroundColor Green -NoNewline; Write-Host "] DISM Component Store Check [dism.exe /Image /Cleanup-Image /CheckHealth]"
    Write-Host "   [" -NoNewline; Write-Host "A" -ForegroundColor Green -NoNewline; Write-Host "] Run All Selected Scans"
    Draw-Divider

    $selection = Read-Host "Choose options (e.g. 1,2 or A)"
    Draw-Header

    if ($selection -match "1" -or $selection -eq "A") { Scan-CoreFiles }
    if ($selection -match "2" -or $selection -eq "A") { Scan-Directories }
    if ($selection -match "3" -or $selection -eq "A") { Scan-OfflineServices }
    if ($selection -match "4" -or $selection -eq "A") { Scan-ComponentStoreHealth }

    Wait-KeyPress
}

function Menu-CustomRepairs {
    Draw-Header
    Write-Host "Select Repair Actions:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "   [" -NoNewline; Write-Host "1" -ForegroundColor Green -NoNewline; Write-Host "] Run Offline SFC Scan [sfc /scannow /offbootdir /offwindir]"
    Write-Host "   [" -NoNewline; Write-Host "2" -ForegroundColor Green -NoNewline; Write-Host "] Run Offline DISM Repair [dism.exe /Image /Cleanup-Image /RestoreHealth]"
    Write-Host "   [" -NoNewline; Write-Host "3" -ForegroundColor Green -NoNewline; Write-Host "] Run Disk Check [chkdsk /f /r /x]"
    Write-Host "   [" -NoNewline; Write-Host "4" -ForegroundColor Green -NoNewline; Write-Host "] Run Boot Repair [bootrec /fixmbr /fixboot /rebuildbcd]"
    Write-Host "   [" -NoNewline; Write-Host "5" -ForegroundColor Green -NoNewline; Write-Host "] Restore Missing Essential System Directories"
    Draw-Divider

    $selection = Read-Host "Choose options to run (e.g. 1,3)"
    Draw-Header

    if ($selection -match "1") { Repair-SFC }
    if ($selection -match "2") { Repair-DISM }
    if ($selection -match "3") { Repair-Chkdsk }
    if ($selection -match "4") { Repair-BootRec }
    if ($selection -match "5") { Repair-Directories }

    Wait-KeyPress
}

$Global:IsRunning = $true

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
        "Q" { 
            Clear-Host
            $Global:IsRunning = $false 
        }
    }
} while ($Global:IsRunning)
