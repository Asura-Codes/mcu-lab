<#
Interactively select an OpenOCD target config and set OPENOCD_TARGET.
Dot-source after path.ps1: . "$PSScriptRoot\target.ps1"

Skips the prompt when OPENOCD_TARGET is already set.
#>

if ($env:OPENOCD_TARGET) {
    Write-Host "[target] Already set: $env:OPENOCD_TARGET" -ForegroundColor Cyan
    return
}

if (-not $env:OPENOCD_SCRIPTS -or -not (Test-Path $env:OPENOCD_SCRIPTS)) {
    Write-Host "[target] OPENOCD_SCRIPTS not set. Run path.ps1 first." -ForegroundColor Yellow
    return
}

$targetDir = Join-Path $env:OPENOCD_SCRIPTS 'target'
$files = @(Get-ChildItem -Path $targetDir -File -Filter '*.cfg' -ErrorAction SilentlyContinue |
    ForEach-Object { $_.Name } | Sort-Object)

if ($files.Count -eq 0) {
    Write-Host "[target] No .cfg files found under $targetDir" -ForegroundColor Yellow; return
}

Write-Host "Available target configs:" -ForegroundColor Cyan
for ($i = 0; $i -lt $files.Count; $i++) { Write-Host "  [$i] $($files[$i])" }
$s = Read-Host "Select index (leave blank to skip)"
if ($s -match '^\d+$' -and [int]$s -lt $files.Count) {
    $env:OPENOCD_TARGET = $files[[int]$s]
    Write-Host "[target] Selected: $env:OPENOCD_TARGET" -ForegroundColor Green
}
else {
    Write-Host "[target] No target selected." -ForegroundColor Yellow
}
