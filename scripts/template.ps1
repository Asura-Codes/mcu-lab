<#
Select a project template and deduce default OpenOCD interface / target configs.
Dot-source after path.ps1: . "$PSScriptRoot\template.ps1"

Sets environment variables:
  OPENOCD_TEMPLATE_NAME  template folder name (e.g. stm32f103)
  OPENOCD_TEMPLATE_PATH  full path to the template folder
  OPENOCD_INTERFACE      default interface config for this template (if not already set)
  OPENOCD_TARGET         default target config for this template (if not already set)

Pre-set OPENOCD_TEMPLATE_NAME before dot-sourcing to skip the interactive prompt.
Interface/target deduction reads the maps from config.ps1 and verifies each config
file actually exists in OPENOCD_SCRIPTS before applying it.
#>

. "$PSScriptRoot\config.ps1"

$_tmplDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'templates'

# ── Template selection ───────────────────────────────────────────────────────
if ($env:OPENOCD_TEMPLATE_NAME) {
    Write-Host "[template] Using preset template: $env:OPENOCD_TEMPLATE_NAME" -ForegroundColor Cyan
    if (-not $env:OPENOCD_TEMPLATE_PATH) {
        $env:OPENOCD_TEMPLATE_PATH = Join-Path $_tmplDir $env:OPENOCD_TEMPLATE_NAME
    }
}
else {
    $dirs = @(Get-ChildItem -Path $_tmplDir -Directory -ErrorAction SilentlyContinue | Sort-Object Name)
    if ($dirs.Count -eq 0) {
        Write-Host "[template] No templates found under $_tmplDir" -ForegroundColor Yellow
        return
    }
    Write-Host "Available templates:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $dirs.Count; $i++) { Write-Host "  [$i] $($dirs[$i].Name)" }
    $s = Read-Host "Select template index (leave blank to skip)"
    if (-not ($s -match '^\d+$') -or [int]$s -ge $dirs.Count) {
        Write-Host "[template] No template selected." -ForegroundColor Yellow
        return
    }
    $env:OPENOCD_TEMPLATE_NAME = $dirs[[int]$s].Name
    $env:OPENOCD_TEMPLATE_PATH = $dirs[[int]$s].FullName
    Write-Host "[template] Selected: $env:OPENOCD_TEMPLATE_NAME" -ForegroundColor Green
}

# ── Deduce interface from map ────────────────────────────────────────────────
if (-not $env:OPENOCD_INTERFACE -and $OcdInterfaceMap.ContainsKey($env:OPENOCD_TEMPLATE_NAME)) {
    $candidate = $OcdInterfaceMap[$env:OPENOCD_TEMPLATE_NAME]
    if ($candidate -and $env:OPENOCD_SCRIPTS) {
        if (Test-Path (Join-Path $env:OPENOCD_SCRIPTS "interface\$($candidate.Replace('/', '\'))")) {
            $env:OPENOCD_INTERFACE = $candidate
            Write-Host "[template] Deduced interface: $candidate" -ForegroundColor Green
        }
        else {
            Write-Host "[template] Mapped interface '$candidate' not found in OPENOCD_SCRIPTS/interface; will prompt." -ForegroundColor Yellow
        }
    }
}

# ── Deduce target from map ───────────────────────────────────────────────────
if (-not $env:OPENOCD_TARGET -and $OcdTargetMap.ContainsKey($env:OPENOCD_TEMPLATE_NAME)) {
    $candidate = $OcdTargetMap[$env:OPENOCD_TEMPLATE_NAME]
    if ($candidate -and $env:OPENOCD_SCRIPTS) {
        if (Test-Path (Join-Path $env:OPENOCD_SCRIPTS "target\$candidate")) {
            $env:OPENOCD_TARGET = $candidate
            Write-Host "[template] Deduced target: $candidate" -ForegroundColor Green
        }
        else {
            Write-Host "[template] Mapped target '$candidate' not found in OPENOCD_SCRIPTS/target; will prompt." -ForegroundColor Yellow
        }
    }
}
