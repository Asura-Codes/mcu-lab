# Windows Tools Installation for Embedded Development
# This PowerShell script helps you install flashing and debugging tools on Windows

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Embedded Development Tools Installer" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Host "[WARN] Not running as Administrator. Some operations may fail." -ForegroundColor Yellow
    Write-Host "[INFO] Consider running: Start-Process powershell -Verb RunAs" -ForegroundColor Yellow
    Write-Host ""
}

# Setup paths
$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition }
if (-not $scriptDir) { $scriptDir = Get-Location }
$repoRoot = Split-Path -Parent $scriptDir
$openocdDir = Join-Path $repoRoot 'openocd'
$flashDir = Join-Path $repoRoot 'flash'
$downloads = Join-Path $env:USERPROFILE 'Downloads'

if (-not (Test-Path $downloads)) { New-Item -ItemType Directory -Path $downloads | Out-Null }
if (-not (Test-Path $openocdDir)) { New-Item -ItemType Directory -Path $openocdDir | Out-Null }
if (-not (Test-Path $flashDir)) { New-Item -ItemType Directory -Path $flashDir | Out-Null }

Write-Host "Installation directories:" -ForegroundColor Cyan
Write-Host "  OpenOCD: $openocdDir" -ForegroundColor Gray
Write-Host "  Flash tools: $flashDir" -ForegroundColor Gray
Write-Host ""

Write-Host "========================================" -ForegroundColor Yellow
Write-Host "OpenOCD Selection Guide" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "Choose ONE OpenOCD variant based on your primary platform:" -ForegroundColor Cyan
Write-Host ""
Write-Host "  - OpenOCD-xPack: Universal, works with all platforms" -ForegroundColor Gray
Write-Host "    Best for: Multi-platform development" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  - OpenOCD-Pico (in Pico SDK Tools): Optimized for Raspberry Pi Pico" -ForegroundColor Gray
Write-Host "    Best for: Pico-focused development" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  - OpenOCD-ESP32: Optimized for ESP32 family (includes RISC-V support)" -ForegroundColor Gray
Write-Host "    Best for: ESP32-focused development" -ForegroundColor DarkGray
Write-Host ""
Write-Host "Note: Installing multiple OpenOCD versions may cause PATH conflicts." -ForegroundColor Yellow
Write-Host "      Choose the one that matches your primary use case." -ForegroundColor Yellow
Write-Host ""

# ============================================
# Tool Definitions
# ============================================

# Use ordered dictionary to maintain display order
$tools = [ordered]@{
    'OpenOCD-xPack' = @{
        Name        = 'OpenOCD (xPack)'
        Url         = 'https://github.com/xpack-dev-tools/openocd-xpack/releases/download/v0.12.0-7/xpack-openocd-0.12.0-7-win32-x64.zip'
        FileName    = 'xpack-openocd-0.12.0-7-win32-x64.zip'
        Description = 'Universal OpenOCD for all platforms (STM32, Pico, ESP32)'
        InstallDir  = 'openocd'
    }
    'OpenOCD-Pico'  = @{
        Name         = 'OpenOCD (Raspberry Pi)'
        Url          = 'https://github.com/raspberrypi/pico-sdk-tools/releases/download/v2.0.0-4/openocd-0.12.0+dev-x64-win.zip'
        FileName     = 'openocd-0.12.0+dev-x64-win.zip'
        Description  = 'Raspberry Pi optimized OpenOCD (standalone)'
        Note         = 'Standalone OpenOCD for Pico - lighter than full PicoSDKTools'
        InstallDir   = 'openocd'
        TargetSubDir = 'pico'
    }
    'OpenOCD-ESP32' = @{
        Name        = 'OpenOCD (Espressif)'
        Url         = 'https://github.com/espressif/openocd-esp32/releases/download/v0.12.0-esp32-20260304/openocd-esp32-win64-0.12.0-esp32-20260304.zip'
        FileName    = 'openocd-esp32-win64-0.12.0-esp32-20251215.zip'
        Description = 'Espressif optimized OpenOCD (recommended for ESP32 debugging)'
        Note        = 'Supports ESP32, ESP32-S2/S3, ESP32-C3 (RISC-V)'
        InstallDir  = 'openocd'
    }
    'PicoSDKTools'  = @{
        Name         = 'Pico SDK Tools'
        Url          = 'https://github.com/raspberrypi/pico-sdk-tools/releases/download/v2.2.0-3/pico-sdk-tools-2.2.0-x64-win.zip'
        FileName     = 'pico-sdk-tools-2.2.0-x64-win.zip'
        Description  = 'Pico SDK Tools (limited release): contains only pioasm.exe'
        Note         = 'Standalone pioasm executable for Pico development'
        InstallDir   = 'flash'
        TargetSubDir = 'pico-sdk-tools'
    }
    'Picotool'      = @{
        Name         = 'Picotool (standalone)'
        Url          = 'https://github.com/raspberrypi/pico-sdk-tools/releases/download/v2.2.0-3/picotool-2.2.0-a4-x64-win.zip'
        FileName     = 'picotool-2.2.0-a4-x64-win.zip'
        Description  = 'Raspberry Pi Pico flashing tool (standalone, lighter than full SDK)'
        Note         = 'Standalone picotool - use this if you only need flashing without full SDK'
        InstallDir   = 'flash'
        TargetSubDir = 'picotool'
    }
    'ESPTool'       = @{
        Name        = 'esptool.py (Python package)'
        Url         = 'pip'
        Description = 'ESP32 flashing tool (requires Python 3)'
        InstallDir  = 'pip'
    }
    'ArduinoCLI'    = @{
        Name         = 'Arduino CLI'
        Url          = 'https://github.com/arduino/arduino-cli/releases/download/v1.4.1/arduino-cli_1.4.1_Windows_64bit.zip'
        FileName     = 'arduino-cli_1.4.1_Windows_64bit.zip'
        Description  = 'Arduino CLI for compiling and uploading Arduino sketches on Windows'
        InstallDir   = 'flash'
        TargetSubDir = 'arduino-cli'
        Note         = 'Adds arduino-cli executable for building and uploading sketches (ESP8266/Arduino)'
    }
    'Zadig'         = @{
        Name         = 'Zadig USB Driver Tool'
        Url          = 'https://github.com/pbatard/libwdi/releases/download/v1.5.1/ZADIG-2.9.exe'
        FileName     = 'ZADIG-2.9.exe'
        Description  = 'USB driver installation tool for Pico, debuggers, and other USB devices'
        InstallDir   = 'flash'
        TargetSubDir = 'zadig'
        Type         = 'exe'
        Note         = 'Required for installing WinUSB drivers for Raspberry Pi Pico and J-Link clone debuggers'
    }
}

# ============================================
# Display Available Tools
# ============================================

Write-Host "Available tools to install:" -ForegroundColor Yellow
Write-Host ""
$index = 1
foreach ($key in $tools.Keys) {
    $tool = $tools[$key]
    Write-Host "$index. $($tool.Name)" -ForegroundColor Green
    Write-Host "   $($tool.Description)" -ForegroundColor Gray
    if ($tool.Note) {
        Write-Host "   Note: $($tool.Note)" -ForegroundColor Yellow
    }
    if ($tool.Url -ne 'pip') {
        Write-Host "   URL: $($tool.Url)" -ForegroundColor DarkGray
    }
    Write-Host ""
    $index++
}

# ============================================
# Tool Selection
# ============================================

Write-Host "Select tools to install:" -ForegroundColor Cyan
Write-Host "  - Enter numbers (comma-separated, e.g., 1,2,3)" -ForegroundColor Gray
Write-Host "  - Enter 'all' to install everything" -ForegroundColor Gray
Write-Host "  - Press Enter for 'all'" -ForegroundColor Gray
Write-Host ""
$selection = Read-Host "Selection"

$selectedTools = @()
if ($selection -eq 'all' -or $selection -eq '') {
    $selectedTools = $tools.Keys
}
else {
    $indices = $selection -split ',' | ForEach-Object { $_.Trim() }
    $toolKeys = @($tools.Keys)
    foreach ($idx in $indices) {
        if ($idx -match '^\d+$') {
            $arrayIndex = [int]$idx - 1
            if ($arrayIndex -ge 0 -and $arrayIndex -lt $toolKeys.Count) {
                $selectedTools += $toolKeys[$arrayIndex]
            }
            else {
                Write-Host "[WARN] Invalid selection: $idx (valid range: 1-$($toolKeys.Count))" -ForegroundColor Yellow
            }
        }
    }
}

if ($selectedTools.Count -eq 0) {
    Write-Host "[INFO] No valid tools selected. Exiting." -ForegroundColor Yellow
    exit
}

Write-Host ""
Write-Host "Selected tools:" -ForegroundColor Cyan
foreach ($toolKey in $selectedTools) {
    Write-Host "  - $($tools[$toolKey].Name)" -ForegroundColor Green
}
Write-Host ""

# Clean directories if installing all tools
if ($selection -eq 'all' -or $selection -eq '') {
    Write-Host "[INFO] Cleaning installation directories..." -ForegroundColor Yellow
    if (Test-Path $openocdDir) {
        Remove-Item "$openocdDir\*" -Recurse -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path $flashDir) {
        Remove-Item "$flashDir\*" -Recurse -Force -ErrorAction SilentlyContinue
    }
    Write-Host "[OK] Directories cleaned" -ForegroundColor Green
    Write-Host ""
}

# ============================================
# Installation Functions
# ============================================

function Install-ZipTool {
    param (
        [string]$Name,
        [string]$Url,
        [string]$FileName,
        [string]$InstallDir,
        [string]$TargetSubDir
    )

    Write-Host "[INFO] Installing $Name..." -ForegroundColor Cyan

    # Determine base directory
    $baseDir = switch ($InstallDir) {
        'openocd' { $openocdDir }
        'flash' { $flashDir }
        default { $repoRoot }
    }

    # Download if needed
    $destPath = Join-Path $downloads $FileName
    if (-not (Test-Path $destPath)) {
        Write-Host "[INFO] Downloading $FileName..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri $Url -OutFile $destPath -UseBasicParsing -ErrorAction Stop
            Write-Host "[OK] Download complete" -ForegroundColor Green
        }
        catch {
            Write-Host "[ERROR] Download failed: $_" -ForegroundColor Red
            return $false
        }
    }
    else {
        Write-Host "[INFO] Using cached file: $FileName" -ForegroundColor Green
    }

    # Extract
    $extractTarget = if ($TargetSubDir) { Join-Path $baseDir $TargetSubDir } else { $baseDir }
    Write-Host "[INFO] Extracting to $extractTarget..." -ForegroundColor Cyan

    try {
        if ($TargetSubDir -and (Test-Path $extractTarget)) {
            Remove-Item $extractTarget -Recurse -Force
        }
        if ($TargetSubDir) {
            New-Item -ItemType Directory -Path $extractTarget -Force | Out-Null
        }

        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($destPath, $extractTarget)

        Write-Host "[OK] Extraction complete" -ForegroundColor Green
        return $extractTarget
    }
    catch {
        try {
            Expand-Archive -LiteralPath $destPath -DestinationPath $extractTarget -Force -ErrorAction Stop
            Write-Host "[OK] Extraction complete" -ForegroundColor Green
            return $extractTarget
        }
        catch {
            Write-Host "[ERROR] Extraction failed: $_" -ForegroundColor Red
            return $false
        }
    }
}

function Install-PythonPackage {
    param (
        [string]$Name,
        [string]$PackageName
    )

    Write-Host "[INFO] Installing $Name via pip..." -ForegroundColor Cyan

    # Check Python
    try {
        $pythonVersion = & python --version 2>&1
        Write-Host "[OK] Python found: $pythonVersion" -ForegroundColor Green
    }
    catch {
        Write-Host "[ERROR] Python not found. Please install Python 3 from https://www.python.org/" -ForegroundColor Red
        return $false
    }

    # Install package
    try {
        Write-Host "[INFO] Running: pip install $PackageName" -ForegroundColor Cyan
        & pip install $PackageName
        Write-Host "[OK] Package installed" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "[ERROR] pip install failed: $_" -ForegroundColor Red
        return $false
    }
}

function Install-ExecutableTool {
    param (
        [string]$Name,
        [string]$Url,
        [string]$FileName,
        [string]$InstallDir,
        [string]$TargetSubDir
    )

    Write-Host "[INFO] Installing $Name..." -ForegroundColor Cyan

    # Determine base directory
    $baseDir = switch ($InstallDir) {
        'openocd' { $openocdDir }
        'flash' { $flashDir }
        default { $repoRoot }
    }

    # Determine target directory
    $targetDir = if ($TargetSubDir) { Join-Path $baseDir $TargetSubDir } else { $baseDir }

    # Create target directory if needed
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }

    # Download file
    $destPath = Join-Path $targetDir $FileName
    Write-Host "[INFO] Downloading $FileName to $targetDir..." -ForegroundColor Cyan

    try {
        Invoke-WebRequest -Uri $Url -OutFile $destPath -UseBasicParsing -ErrorAction Stop
        Write-Host "[OK] Download complete: $destPath" -ForegroundColor Green
        return $targetDir
    }
    catch {
        Write-Host "[ERROR] Download failed: $_" -ForegroundColor Red
        return $false
    }
}

# ============================================
# Install Selected Tools
# ============================================

$installResults = @{}

foreach ($toolKey in $selectedTools) {
    $tool = $tools[$toolKey]
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Installing: $($tool.Name)" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan

    $success = $false

    if ($tool.Url -eq 'pip') {
        $success = Install-PythonPackage -Name $tool.Name -PackageName 'esptool'
    }
    elseif ($tool.Type -eq 'exe') {
        $installPath = Install-ExecutableTool -Name $tool.Name -Url $tool.Url -FileName $tool.FileName -InstallDir $tool.InstallDir -TargetSubDir $tool.TargetSubDir
        if ($installPath) {
            $success = $true
        }
    }
    else {
        $extractPath = Install-ZipTool -Name $tool.Name -Url $tool.Url -FileName $tool.FileName -InstallDir $tool.InstallDir -TargetSubDir $tool.TargetSubDir
        if ($extractPath) {
            $success = $true
        }
    }

    $installResults[$toolKey] = $success
}

# ============================================
# Summary
# ============================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Installation Complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$successfulInstalls = @($installResults.Values | Where-Object { $_ -eq $true })
$successCount = $successfulInstalls.Count
Write-Host "Successfully installed: $successCount / $($selectedTools.Count) tools" -ForegroundColor $(if ($successCount -eq $selectedTools.Count) { 'Green' } else { 'Yellow' })
Write-Host ""

Write-Host "Tool locations:" -ForegroundColor Cyan
Write-Host "  OpenOCD: $openocdDir" -ForegroundColor Gray
Write-Host "  Flash tools: $flashDir" -ForegroundColor Gray
Write-Host "  Downloads: $downloads" -ForegroundColor Gray
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Recommended Tool Combinations" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "For ESP32 development:" -ForegroundColor Green
Write-Host "  - ESPTool (required for flashing)" -ForegroundColor Gray
Write-Host "  - OpenOCD-ESP32 OR OpenOCD-xPack (for debugging)" -ForegroundColor Gray
Write-Host ""
Write-Host "For Arduino / ESP8266 development:" -ForegroundColor Green
Write-Host "  - Arduino CLI (compile + upload)" -ForegroundColor Gray
Write-Host "  - esptool.py (for manual flashing when needed)" -ForegroundColor Gray
Write-Host ""
Write-Host "For Raspberry Pi Pico development:" -ForegroundColor Green
Write-Host "  - PicoSDKTools (includes picotool + OpenOCD + GDB)" -ForegroundColor Gray
Write-Host "  OR" -ForegroundColor Gray
Write-Host "  - Picotool + OpenOCD-Pico (for lightweight setup)" -ForegroundColor Gray
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "USB Driver Requirements" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "ESP32: CP210x or FTDI drivers" -ForegroundColor Green
Write-Host "  https://www.silabs.com/developers/usb-to-uart-bridge-vcp-drivers" -ForegroundColor Gray
Write-Host ""

Write-Host "Raspberry Pi Pico: WinUSB driver via Zadig" -ForegroundColor Green
Write-Host "  https://zadig.akeo.ie/" -ForegroundColor Gray
Write-Host ""

