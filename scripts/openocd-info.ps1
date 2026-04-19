<#
Discover detailed chip information via OpenOCD.

Connects with the chosen interface and probes candidate target configs to identify
the chip, report CPU type, flash regions, and silicon details.

Why target probing instead of scan_chain:
  scan_chain is JTAG-only.  ST-Link uses SWD where there is no JTAG chain to scan.
  The only way to read chip-specific info (DPIDR, flash map, CPU revision) with
  SWD is to load a target config, run init, and query the DAP after it connects.

Strategy:
  1. If -Target is given, probe that target only.
  2. Otherwise, build candidate list from $OcdProbeTargets[interface] in config.ps1.
  3. For each candidate: run init + targets + flash list.  Stop at first success
     (or probe all when -SelectTarget is set).
  4. Print full chip details for every successful probe.
  5. With -SelectTarget, prompt user to choose and export OPENOCD_TARGET.

Parameters:
  -Interface     Interface config (e.g. stlink.cfg). Prompt if omitted or 'auto'.
  -Target        Specific target to probe directly, bypassing auto-discovery.
  -SelectTarget  Probe all candidates and prompt for selection (sets OPENOCD_TARGET).
  -AdapterSpeed  Adapter clock in kHz (default 1000).

Examples:
  .\openocd-info.ps1                                        interactive interface
  .\openocd-info.ps1 -Interface stlink.cfg                  auto-discover chip
  .\openocd-info.ps1 -Interface stlink.cfg -Target stm32f4x.cfg   direct probe
  .\openocd-info.ps1 -Interface stlink.cfg -SelectTarget    probe all + pick target
#>

param(
    [string]$Interface   = '',
    [string]$Target      = '',
    [switch]$SelectTarget,
    [int]   $AdapterSpeed = 1000
)

. "$PSScriptRoot\config.ps1"

try {
    . "$PSScriptRoot\path.ps1" | Out-Null
    if (-not $env:OPENOCD_EXE -or -not (Test-Path $env:OPENOCD_EXE)) {
        Write-Host "[info] OPENOCD_EXE not found. Run path.ps1 first." -ForegroundColor Red; exit 1
    }
    if (-not $env:OPENOCD_SCRIPTS -or -not (Test-Path $env:OPENOCD_SCRIPTS)) {
        Write-Host "[info] OPENOCD_SCRIPTS not found. Run path.ps1 first." -ForegroundColor Red; exit 1
    }

    # ── Resolve interface ─────────────────────────────────────────────────────
    if ($Interface -and $Interface -ne 'auto') {
        $env:OPENOCD_INTERFACE = Add-CfgExt $Interface
    } elseif (-not $env:OPENOCD_INTERFACE) {
        . "$PSScriptRoot\interface.ps1"
    }
    $iface = $env:OPENOCD_INTERFACE
    if (-not $iface) { Write-Host "[info] No interface selected; exiting." -ForegroundColor Yellow; exit 0 }

    $ifacePath = Join-Path $env:OPENOCD_SCRIPTS "interface\$($iface.Replace('/','\'))"
    if (-not (Test-Path $ifacePath)) {
        Write-Host "[info] Interface file not found: $ifacePath" -ForegroundColor Red; exit 2
    }

    if ($env:OPENOCD_ADAPTER_KHZ) { $AdapterSpeed = [int]$env:OPENOCD_ADAPTER_KHZ }

    Write-Host ""
    Write-Host "=== OpenOCD Target Info ===" -ForegroundColor Green
    Write-Host "  Executable : $env:OPENOCD_EXE"
    Write-Host "  Interface  : $iface  ($AdapterSpeed kHz)"
    Write-Host ""

    # ── Phase 1: adapter-only init to verify connection and get voltage ───────
    Write-Host "Phase 1: Verifying adapter connection..." -ForegroundColor Cyan
    $a0  = Build-OcdArgs $env:OPENOCD_SCRIPTS $iface ''
    $a0 += '-c', "adapter speed $AdapterSpeed"
    $a0 += '-c', 'init'
    $a0 += '-c', 'exit'
    Write-OcdCmd $env:OPENOCD_EXE $a0
    $out0  = & $env:OPENOCD_EXE @a0 2>&1
    $text0 = $out0 -join "`n"
    $out0 | Where-Object { $_ -match '^(Info|Warn) :' } | ForEach-Object { Write-Host "  $_" }

    $adapterOk = $LASTEXITCODE -eq 0 -and -not (
        $text0 -match '(?i)No .* found|unable to find|failed to (open|claim)|Error:.*not found')
    if (-not $adapterOk) {
        Write-Host ""
        Write-Host "[info] Adapter not responding. Check USB connection and interface config." -ForegroundColor Red
        exit 3
    }
    Write-Host ""

    # ── Phase 2: target probing ───────────────────────────────────────────────
    # Build candidate list: explicit -Target > OPENOCD_TARGET env > auto-probe list.
    if ($Target -and $Target -ne 'auto') {
        $candidates = @(Add-CfgExt $Target)
    } elseif ($env:OPENOCD_TARGET) {
        $candidates = @($env:OPENOCD_TARGET)
        Write-Host "[info] Using preset OPENOCD_TARGET: $env:OPENOCD_TARGET" -ForegroundColor Cyan
    } else {
        $candidates = @(Get-OcdProbeTargets $iface | Where-Object {
            Test-Path (Join-Path $env:OPENOCD_SCRIPTS "target\$_")
        })
    }

    if ($candidates.Count -eq 0) {
        Write-Host "[info] No candidate targets for interface '$iface'." -ForegroundColor Yellow
        Write-Host "[info] Specify -Target explicitly (e.g. -Target stm32f1x.cfg)." -ForegroundColor Yellow
        exit 0
    }

    Write-Host "Phase 2: Probing $($candidates.Count) target candidate(s)..." -ForegroundColor Cyan
    Write-Host ""

    $hits = @()

    foreach ($t in $candidates) {
        Write-Host "── Target: $t" -ForegroundColor Cyan
        $a  = Build-OcdArgs $env:OPENOCD_SCRIPTS $iface $t
        $a += '-c', "adapter speed $AdapterSpeed"
        $a += '-c', 'init'
        $a += '-c', 'targets'
        $a += '-c', 'flash list'
        $a += '-c', 'exit'

        Write-OcdCmd $env:OPENOCD_EXE $a
        $out  = & $env:OPENOCD_EXE @a 2>&1
        $text = $out -join "`n"

        # Print all output — full chip details are here.
        $out | ForEach-Object { Write-Host "  $_" }
        Write-Host ""

        $success = $LASTEXITCODE -eq 0 -and
            $text -match '(?i)Examination succeed|target halted|halted due to|flash|detected'
        if ($success) {
            $hits += $t
            if (-not $SelectTarget) { break }   # stop at first hit when not selecting
        }
    }

    if ($hits.Count -eq 0) {
        Write-Host "[info] No target responded. Possible causes:" -ForegroundColor Yellow
        Write-Host "  - Wrong target config for the connected chip" -ForegroundColor Yellow
        Write-Host "  - Target not powered or in a locked state" -ForegroundColor Yellow
        Write-Host "  - Try -AdapterSpeed 250 or -Target <specific.cfg>" -ForegroundColor Yellow
        exit 0
    }

    # ── Optional interactive target selection ─────────────────────────────────
    if (-not $SelectTarget -or $hits.Count -eq 0) {
        Write-Host "[info] Use OPENOCD_TARGET=$($hits[0]) or pass -Target $($hits[0]) to other scripts." -ForegroundColor Green
        exit 0
    }

    Write-Host "Responding targets:" -ForegroundColor Green
    for ($i = 0; $i -lt $hits.Count; $i++) { Write-Host "  [$i] $($hits[$i])" }

    $sel = $null
    if ($env:OPENOCD_AUTOSELECT) {
        $sel = if ($env:OPENOCD_AUTOSELECT -match '(?i)^first$') { '0' } else { $env:OPENOCD_AUTOSELECT }
        Write-Host "[info] Auto-select: $sel" -ForegroundColor Cyan
    }
    if (-not $sel) { $sel = Read-Host "Select index (leave blank to skip)" }

    if ($sel -match '^\d+$' -and [int]$sel -lt $hits.Count) {
        $env:OPENOCD_TARGET = $hits[[int]$sel]
        Write-Host "[info] OPENOCD_TARGET = $env:OPENOCD_TARGET" -ForegroundColor Green
    }
}
finally {
    Clear-OcdEnv
}

