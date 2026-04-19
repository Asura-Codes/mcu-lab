<#
Discover OpenOCD executables under <repo>/openocd/ and set OPENOCD_EXE / OPENOCD_SCRIPTS.
Dot-source from any OpenOCD helper script: . "$PSScriptRoot\path.ps1"

Searches three package layouts present under openocd/:
  xPack / ESP32  {pkg}/bin/openocd.exe  +  {pkg}/share/openocd/scripts
  xPack (alt)   {pkg}/bin/openocd.exe  +  {pkg}/openocd/scripts
  Pico          {pkg}/openocd.exe      +  {pkg}/scripts

Respects OPENOCD_EXE when already set and the path exists.
When the template is already known, automatically prefers the bundled OpenOCD
package that matches that family:
  ESP32      -> openocd-esp32
  RP2040/RP2350/nRF52 -> pico
  STM32 and everything else -> xPack
Prompts when multiple executables are found and no template-specific preference
can be applied.
#>

$_ocdRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'openocd'

function Get-OcdPackageKind([string]$exePath) {
    if (-not $exePath) { return '' }
    $normalized = $exePath.Replace('/', '\').ToLower()
    if ($normalized -match '\\openocd\\pico(\\|$)') { return 'pico' }
    if ($normalized -match '\\openocd\\openocd-esp32(\\|$)') { return 'esp32' }
    if ($normalized -match '\\openocd\\xpack-openocd-') { return 'xpack' }
    return ''
}

function Get-OcdPreferredPackageKind([string]$templateName, [string]$ifaceName) {
    $ifaceBase = ''
    if ($ifaceName) {
        $ifaceBase = [IO.Path]::GetFileNameWithoutExtension($ifaceName).ToLower()
    }

    # Interface capability wins over template preference.
    if ($ifaceBase -eq 'jlink') { return 'xpack' }
    if ($ifaceBase -match '^esp_usb_jtag$|^esp_ftdi$') { return 'esp32' }

    if (-not $templateName) { return '' }

    switch -Regex ($templateName.ToLower()) {
        '^esp' { return 'esp32' }
        '^(rp2040|rp2350|nrf52840)$' { return 'pico' }
        default { return 'xpack' }
    }
}

# ── Select executable ────────────────────────────────────────────────────────
if ($env:OPENOCD_EXE -and (Test-Path $env:OPENOCD_EXE)) {
    Write-Host "[path] Preset OPENOCD_EXE: $env:OPENOCD_EXE" -ForegroundColor Cyan
}
else {
    $candidates = @(Get-ChildItem -Path $_ocdRoot -Recurse -File -Filter 'openocd.exe' -ErrorAction SilentlyContinue | Sort-Object FullName)
    if ($candidates.Count -eq 0) {
        $env:OPENOCD_EXE = ''
        Write-Host "[path] No openocd.exe found under $_ocdRoot" -ForegroundColor Yellow
    }
    elseif ($candidates.Count -eq 1) {
        $env:OPENOCD_EXE = $candidates[0].FullName
        Write-Host "[path] Found: $env:OPENOCD_EXE" -ForegroundColor Green
    }
    else {
        $preferredKind = Get-OcdPreferredPackageKind $env:OPENOCD_TEMPLATE_NAME $env:OPENOCD_INTERFACE
        $preferredCandidates = if ($preferredKind) {
            @($candidates | Where-Object { (Get-OcdPackageKind $_.FullName) -eq $preferredKind })
        }
        else {
            @()
        }

        if ($preferredCandidates.Count -gt 0 -and ($env:OPENOCD_TEMPLATE_NAME -or $env:OPENOCD_INTERFACE)) {
            $env:OPENOCD_EXE = $preferredCandidates[0].FullName
            $reason = if ($env:OPENOCD_TEMPLATE_NAME) { "template '$($env:OPENOCD_TEMPLATE_NAME)'" } else { "interface '$($env:OPENOCD_INTERFACE)'" }
            Write-Host "[path] Selected preferred OpenOCD for ${reason}: $env:OPENOCD_EXE" -ForegroundColor Green
        }
        else {
            Write-Host "[path] Multiple OpenOCD executables found:" -ForegroundColor Cyan
            for ($i = 0; $i -lt $candidates.Count; $i++) { Write-Host "  [$i] $($candidates[$i].FullName)" }
            $s = Read-Host "Select index (default 0)"
            $idx = if ($s -match '^\d+$' -and [int]$s -lt $candidates.Count) { [int]$s } else { 0 }
            $env:OPENOCD_EXE = $candidates[$idx].FullName
            Write-Host "[path] Selected: $env:OPENOCD_EXE" -ForegroundColor Green

            if ($preferredKind -and $env:OPENOCD_TEMPLATE_NAME) {
                $selectedKind = Get-OcdPackageKind $env:OPENOCD_EXE
                if ($selectedKind -and $selectedKind -ne $preferredKind) {
                    Write-Host "[path] Warning: '$selectedKind' is not the preferred OpenOCD bundle for template '$($env:OPENOCD_TEMPLATE_NAME)'." -ForegroundColor Yellow
                }
            }
        }
    }
}

# ── Resolve paired scripts directory ────────────────────────────────────────
if ($env:OPENOCD_EXE -and (Test-Path $env:OPENOCD_EXE)) {
    $exeDir = Split-Path -Parent $env:OPENOCD_EXE
    # Walk up one level when the exe lives in a bin/ subdirectory (xPack / ESP32).
    $pkgDir = if ((Split-Path -Leaf $exeDir) -eq 'bin') { Split-Path -Parent $exeDir } else { $exeDir }

    # Check the three known scripts locations in priority order.
    $scriptsDir = @(
        (Join-Path $pkgDir 'share\openocd\scripts'),  # xPack, ESP32 OpenOCD
        (Join-Path $pkgDir 'openocd\scripts'),         # xPack alternative layout
        (Join-Path $pkgDir 'scripts')                  # Pico OpenOCD
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1

    if ($scriptsDir) {
        $env:OPENOCD_SCRIPTS = $scriptsDir
        Write-Host "[path] Scripts: $env:OPENOCD_SCRIPTS" -ForegroundColor Green
    }
    else {
        $env:OPENOCD_SCRIPTS = ''
        Write-Host "[path] No scripts directory found alongside $env:OPENOCD_EXE" -ForegroundColor Yellow
    }
}
