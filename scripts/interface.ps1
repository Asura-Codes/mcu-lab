<#
Interactively select an OpenOCD interface config and set OPENOCD_INTERFACE.
Dot-source after path.ps1: . "$PSScriptRoot\interface.ps1"

Skips the prompt when OPENOCD_INTERFACE is already set.
Lists all .cfg files recursively under OPENOCD_SCRIPTS/interface/.
#>

if ($env:OPENOCD_INTERFACE) {
    Write-Host "[interface] Already set: $env:OPENOCD_INTERFACE" -ForegroundColor Cyan
    return
}

if (-not $env:OPENOCD_SCRIPTS -or -not (Test-Path $env:OPENOCD_SCRIPTS)) {
    Write-Host "[interface] OPENOCD_SCRIPTS not set. Run path.ps1 first." -ForegroundColor Yellow
    return
}

$ifaceDir = Join-Path $env:OPENOCD_SCRIPTS 'interface'
$files = @(Get-ChildItem -Path $ifaceDir -File -Filter '*.cfg' -Recurse -ErrorAction SilentlyContinue |
    ForEach-Object { $_.FullName.Substring($ifaceDir.Length + 1).Replace('\', '/') } | Sort-Object)

if ($files.Count -eq 0) {
    Write-Host "[interface] No .cfg files found under $ifaceDir" -ForegroundColor Yellow; return
}

Write-Host "Available interface configs:" -ForegroundColor Cyan
for ($i = 0; $i -lt $files.Count; $i++) { Write-Host "  [$i] $($files[$i])" }
$s = Read-Host "Select index (leave blank to skip)"
if ($s -match '^\d+$' -and [int]$s -lt $files.Count) {
    $env:OPENOCD_INTERFACE = $files[[int]$s]
    Write-Host "[interface] Selected: $env:OPENOCD_INTERFACE" -ForegroundColor Green
}
else {
    Write-Host "[interface] No interface selected." -ForegroundColor Yellow
}
