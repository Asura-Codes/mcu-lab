<#
Detect connected debug adapters and identify the target chip.

Two-phase process:
  Phase 1 – Adapter: probes common interface configs (stlink, jlink, cmsis-dap,
             esp_usb_jtag, ftdi/esp_ftdi) to find which adapter(s) are connected.
  Phase 2 – Target:  for each found adapter, tries candidate target configs in
             priority order (from $OcdProbeTargets in config.ps1) to identify
             the chip.  Stops at the first target that responds successfully.

No interaction required — just run the task.

Parameters:
  -AdapterSpeed  Adapter clock in kHz used during probing (default 500; lower is
                 safer for unknown / poorly-powered targets).

Examples:
  .\openocd-detect.ps1
  .\openocd-detect.ps1 -AdapterSpeed 250
#>

param([int]$AdapterSpeed = 500)

. "$PSScriptRoot\config.ps1"

try {
    . "$PSScriptRoot\path.ps1" | Out-Null
    if (-not $env:OPENOCD_EXE -or -not (Test-Path $env:OPENOCD_EXE)) {
        Write-Host "[detect] OPENOCD_EXE not found. Run path.ps1 first." -ForegroundColor Red; exit 1
    }
    if (-not $env:OPENOCD_SCRIPTS -or -not (Test-Path $env:OPENOCD_SCRIPTS)) {
        Write-Host "[detect] OPENOCD_SCRIPTS not found. Run path.ps1 first." -ForegroundColor Red; exit 1
    }

    $ifaceDir = Join-Path $env:OPENOCD_SCRIPTS 'interface'
    $priority = @('stlink.cfg', 'jlink.cfg', 'cmsis-dap.cfg', 'esp_usb_jtag.cfg', 'ftdi/esp_ftdi.cfg')
    $probeList = @($priority | Where-Object { Test-Path (Join-Path $ifaceDir $_.Replace('/', '\')) })

    if ($probeList.Count -eq 0) {
        Write-Host "[detect] No probe interfaces found in $ifaceDir" -ForegroundColor Yellow; exit 2
    }

    Write-Host ""
    Write-Host "=== OpenOCD Detect Hardware ===" -ForegroundColor Green
    Write-Host "  Executable  : $env:OPENOCD_EXE"
    Write-Host "  Scripts     : $env:OPENOCD_SCRIPTS"
    Write-Host "  Adapter kHz : $AdapterSpeed"
    Write-Host "  Interfaces  : $($probeList -join ', ')"
    Write-Host ""

    $foundAdapters = @()

    foreach ($iface in $probeList) {
        Write-Host "── Probing adapter: $iface" -ForegroundColor Cyan

        # Phase 1: init with no target — just verify the adapter responds.
        $a1 = Build-OcdArgs $env:OPENOCD_SCRIPTS $iface ''
        $a1 += '-c', "adapter speed $AdapterSpeed"
        $a1 += '-c', 'init'
        $a1 += '-c', 'exit'

        Write-OcdCmd $env:OPENOCD_EXE $a1
        $out1 = & $env:OPENOCD_EXE @a1 2>&1
        $text1 = $out1 -join "`n"

        # Print only Info/Warn lines to keep output concise.
        $out1 | Where-Object { $_ -match '^(Info|Warn) :' } | ForEach-Object { Write-Host "  $_" }

        $adapterFailed = $LASTEXITCODE -ne 0 -or
        $text1 -match '(?i)No .* found|unable to find|failed to (open|claim)|libusb.*error|permission denied|Can.t (connect|open|find)|Error:'

        # Some Espressif USB-JTAG interfaces enumerate but emit setup warnings
        # (for example "There are no enabled taps") and may exit non-zero while
        # still reporting a usable device (VID/PID, serial, "Device found").
        # For esp_usb_jtag, treat those cases as adapter-present so we can
        # proceed to the target probing phase instead of bailing out early.
        if ($adapterFailed -and $iface -match '(?i)esp_usb_jtag' -and
            $text1 -match '(?i)Device found|VID:PID|serial \(|clock speed') {
            $adapterFailed = $false
        }

        if ($adapterFailed) {
            Write-Host "  → No adapter on $iface" -ForegroundColor Yellow
            Write-Host ""
            continue
        }

        Write-Host "  [ADAPTER] Found: $iface" -ForegroundColor Green

        # Extract and show adapter details (voltage, VID/PID).
        $out1 | Where-Object { $_ -match 'VID:PID|voltage|JTAG|SWD|clock speed' } |
        ForEach-Object { Write-Host "    $_" }

        $foundAdapters += $iface

        # Phase 2: try candidate targets ranked by likelihood for this interface.
        Write-Host ""
        Write-Host "  Probing targets..." -ForegroundColor Cyan
        $candidates = @(Get-OcdProbeTargets $iface | Where-Object {
                Test-Path (Join-Path $env:OPENOCD_SCRIPTS "target\$_")
            })

        if ($candidates.Count -eq 0) {
            Write-Host "  No candidate targets configured for $iface. Use openocd-info.ps1." -ForegroundColor Yellow
        }
        else {
            $foundTarget = $false
            foreach ($target in $candidates) {
                $a2 = Build-OcdArgs $env:OPENOCD_SCRIPTS $iface $target
                $a2 += '-c', "adapter speed $AdapterSpeed"
                $a2 += '-c', 'init'
                $a2 += '-c', 'targets'
                $a2 += '-c', 'exit'

                Write-Host "    Trying $target..." -ForegroundColor DarkGray
                $out2 = & $env:OPENOCD_EXE @a2 2>&1
                $text2 = $out2 -join "`n"

                if ($LASTEXITCODE -eq 0 -and $text2 -match '(?i)Examination succeed|target halted|halted due to') {
                    Write-Host "  [TARGET] Identified: $target" -ForegroundColor Green
                    # Print chip details: CPU type, DPIDR, breakpoints, etc.
                    $out2 | Where-Object { $_ -match 'DPIDR|Cortex|processor detected|breakpoints|Examination' } |
                    ForEach-Object { Write-Host "    $_" }
                    Write-Host ""
                    Write-Host "  Tip: set OPENOCD_INTERFACE=$iface and OPENOCD_TARGET=$target to skip probing." -ForegroundColor DarkGray
                    $foundTarget = $true
                    break
                }
            }
            if (-not $foundTarget) {
                Write-Host "  [TARGET] Not identified. Run 'OpenOCD: Target Info' for detailed probing." -ForegroundColor Yellow
            }
        }
        Write-Host ""
    }

    if ($foundAdapters.Count -eq 0) {
        Write-Host "[detect] No adapters found. Check USB connections and drivers (Zadig)." -ForegroundColor Red
        exit 2
    }

    Write-Host "=== Summary ===" -ForegroundColor Green
    Write-Host "  Found adapter(s): $($foundAdapters -join ', ')"
}
finally {
    Clear-OcdEnv
}

