<#
Flash firmware to a target device via OpenOCD.

Platform-aware flashing strategy per template family:
  ESP32 family  Uses program_esp with IDF-standard offsets:
                  bootloader  0x0 (C3/C6) or 0x1000 (all other variants)
                  partition-table  0x8000
                  application      0x10000
  RP2040/RP2350 Programs the .elf file with OpenOCD (verify + reset).
  STM32         Programs the .elf file with OpenOCD (verify + reset).
  nRF52840      Programs build/zephyr/zephyr.elf via OpenOCD (verify + reset).
  Fallback      Uses the newest .elf found in the build directory.

Parameters:
  -Template           Template name or index to skip the interactive prompt.
  -Interface          Interface config override (e.g. jlink.cfg). Pass 'auto' to use the
                      template map default. Allows swapping stlink ↔ jlink, etc.
  -Target             Target config override (e.g. stm32f4x.cfg).
    -QspiFlashSize      QSPI flash size preset for RP targets: auto|1MB|2MB|4MB|8MB|16MB.
  -AdapterSpeed       Adapter clock in kHz (default 1000). Lower values are more reliable
                      over long cables or with poorly powered targets.

Examples:
  .\openocd-flash.ps1                                   interactive
  .\openocd-flash.ps1 -Template stm32f103
  .\openocd-flash.ps1 -Template stm32f103 -Interface jlink.cfg
  .\openocd-flash.ps1 -Template esp32-c3 -AdapterSpeed 500
  .\openocd-flash.ps1 -Template rp2040
#>

param(
    [string]$Template = '',
    [string]$Interface = '',
    [string]$Target = '',
    [string]$QspiFlashSize = '',
    [switch]$VerboseOcd,
    [int]   $AdapterSpeed = 1000,
    [int]   $SrstPulseWidth = 5,
    [int]   $SrstDelay = 500,
    [switch]$NoExec
)

. "$PSScriptRoot\config.ps1"

function Fail([string]$msg) { Write-Host "[flash] ERROR: $msg" -ForegroundColor Red; exit 1 }

try {
    # Resolve template (name or index → OPENOCD_TEMPLATE_NAME/PATH) before path.ps1
    # so it can prefer the matching bundled OpenOCD package.
    if ($Template -and -not $env:OPENOCD_TEMPLATE_NAME) {
        $dirs = @(Get-ChildItem -Path (Join-Path (Split-Path -Parent $PSScriptRoot) 'templates') -Directory |
            Sort-Object Name)
        $m = if ($Template -match '^\d+$') { $dirs[[int]$Template] } else {
            $dirs | Where-Object { $_.Name -ieq $Template } | Select-Object -First 1
        }
        if ($m) {
            $env:OPENOCD_TEMPLATE_NAME = $m.Name
            $env:OPENOCD_TEMPLATE_PATH = $m.FullName
        }
    }
    . "$PSScriptRoot\template.ps1"
    if (-not $env:OPENOCD_TEMPLATE_NAME) { Fail "No template selected." }

    # Apply explicit overrides before path.ps1 so package preference can use them.
    if ($Interface -and $Interface -ne 'auto') {
        $env:OPENOCD_INTERFACE = Add-CfgExt $Interface
        Write-Host "[flash] Interface override: $env:OPENOCD_INTERFACE" -ForegroundColor Cyan
    }
    if ($Target -and $Target -ne 'auto') {
        $env:OPENOCD_TARGET = Add-CfgExt $Target
        Write-Host "[flash] Target override: $env:OPENOCD_TARGET" -ForegroundColor Cyan
    }

    . "$PSScriptRoot\path.ps1" | Out-Null
    if (-not $env:OPENOCD_EXE -or -not (Test-Path $env:OPENOCD_EXE)) { Fail "OPENOCD_EXE not found." }
    if (-not $env:OPENOCD_SCRIPTS -or -not (Test-Path $env:OPENOCD_SCRIPTS)) { Fail "OPENOCD_SCRIPTS not found." }

    # Re-run template deduction in case package-specific script availability changed.
    . "$PSScriptRoot\template.ps1"

    if (-not $env:OPENOCD_INTERFACE) { . "$PSScriptRoot\interface.ps1" }
    if (-not $env:OPENOCD_TARGET) { . "$PSScriptRoot\target.ps1" }

    $templateName = $env:OPENOCD_TEMPLATE_NAME
    $templatePath = $env:OPENOCD_TEMPLATE_PATH
    if (-not $templateName) { Fail "No template selected." }

    $buildDir = Join-Path $templatePath 'build'
    if (-not (Test-Path $buildDir)) { Fail "Build directory not found: $buildDir" }

    Write-Host ""
    Write-Host "=== OpenOCD Flash ===" -ForegroundColor Green
    Write-Host "  Template   : $templateName  ($templatePath)"
    Write-Host "  Interface  : $($env:OPENOCD_INTERFACE)"
    Write-Host "  Target     : $($env:OPENOCD_TARGET)"
    Write-Host "  Adapter    : $($AdapterSpeed) kHz"
    Write-Host ""

    $name = $templateName.ToLower()

    # Load shared helpers for reset handling and QSPI target policy.
    . "$PSScriptRoot\openocd-utils.ps1"

    $preTargetCmds = @()
    if (Test-OcdQspiTarget -Target $env:OPENOCD_TARGET) {
        $sizeSelection = Resolve-OcdQspiFlashSize -RequestedSize $QspiFlashSize -PromptIfMissing
        if ($sizeSelection.IsOverride) {
            $preTargetCmds += "set FLASHSIZE $($sizeSelection.Value)"
            Write-Host "QSPI flash size override: $($sizeSelection.Label) [$($sizeSelection.Value)]" -ForegroundColor Cyan
        }
        else {
            Write-Host "QSPI flash size: auto-detect" -ForegroundColor Cyan
        }
    }

    # ── Build base OpenOCD arguments ────────────────────────────────────────
    $ocdArgs = Build-OcdArgs $env:OPENOCD_SCRIPTS $env:OPENOCD_INTERFACE $env:OPENOCD_TARGET $preTargetCmds

    if ($VerboseOcd) {
        $ocdArgs += '-d3'  # verbose debug output to help troubleshoot config issues
        Write-Host "[server] OpenOCD verbose logging enabled (-d3)." -ForegroundColor Yellow
    }

    $ocdArgs += '-c', "adapter speed $AdapterSpeed"

    $util = Get-OcdResetConfig -Interface $env:OPENOCD_INTERFACE -Target $env:OPENOCD_TARGET
    $resetCfg = $util.ResetConfig

    $ocdArgs += '-c', "adapter srst pulse_width $SrstPulseWidth"
    $ocdArgs += '-c', "adapter srst delay $SrstDelay"
    $ocdArgs += '-c', "reset_config $resetCfg"
    Write-Host "Reset config determined as: $resetCfg [$SrstDelay ms]" -ForegroundColor Cyan
    if ($resetCfg -match 'srst_only') {
        Write-Host "[flash] Note: this mode expects NRST wiring. If NRST is disconnected, switch to an interface/target profile that does not require SRST." -ForegroundColor Yellow
    }

    # ── Determine flash commands by template family ──────────────────────────
    $progCmds = @()

    if ($name -match 'esp') {
        # ESP-IDF build artifacts under build/.
        # Bootloader offset: 0x0 for C3/C6 (ESP-IDF v5+ RISC-V); 0x1000 for all others.
        $bootOffset = if ($name -match 'c3|c6') { '0x0' } else { '0x1000' }

        # Prefer FileInfo objects so later code can reference `.FullName`.
        $bootBin = Get-Item -Path (Join-Path $buildDir 'bootloader\bootloader.bin') -ErrorAction SilentlyContinue
        if (-not $bootBin) {
            $bootBin = Get-ChildItem -Path $buildDir -Recurse -Filter 'bootloader.bin' -File -ErrorAction SilentlyContinue | Select-Object -First 1
        }
        $partBin = Get-Item -Path (Join-Path $buildDir 'partition_table\partition-table.bin') -ErrorAction SilentlyContinue
        if (-not $partBin) {
            $partBin = Get-ChildItem -Path $buildDir -Recurse -Filter 'partition-table.bin' -File -ErrorAction SilentlyContinue | Select-Object -First 1
        }
        $appBin = Find-Elf $buildDir

        Write-Host "[flash] ESP artifacts found:" -ForegroundColor Cyan
        if ($bootBin) { Write-Host "  bootloader    : $($bootBin.FullName)" }
        if ($partBin) { Write-Host "  partition tbl : $($partBin.FullName)" }
        if ($appBin) { Write-Host "  application   : $($appBin.FullName)" }

        if (-not $bootBin -and -not $appBin) { Fail "No ESP32 flash images found under $buildDir" }

        # Prefer IDF's flasher_args.json when available — it lists all partitions and offsets
        $flasherJson = Get-Item -Path (Join-Path $buildDir 'flasher_args.json') -ErrorAction SilentlyContinue
        if (-not $flasherJson) {
            $flasherJson = Get-ChildItem -Path $buildDir -Recurse -Filter 'flasher_args.json' -File -ErrorAction SilentlyContinue | Select-Object -First 1
        }
        if ($flasherJson) {
            # Compute a path relative to buildDir for program_esp_bins (it does a file join)
            if ($flasherJson.FullName.StartsWith($buildDir, [System.StringComparison]::OrdinalIgnoreCase)) {
                $rel = $flasherJson.FullName.Substring($buildDir.Length).TrimStart('\', '/')
            }
            else {
                $rel = $flasherJson.Name
            }
            $rel = $rel -replace '\\', '/'
            $p = Format-OcdPath $buildDir
            Write-Host "[flash] Using flasher_args.json: $($flasherJson.FullName)" -ForegroundColor Cyan
            $progCmds += "program_esp_bins {$p} {$rel} verify exit"
        }
        else {
            if ($bootBin) {
                $p = Format-OcdPath $bootBin.FullName
                $progCmds += "program_esp {$p} $bootOffset"
            }
            if ($partBin) {
                $p = Format-OcdPath $partBin.FullName
                $progCmds += "program_esp {$p} 0x8000"
            }
            if ($appBin) {
                $p = Format-OcdPath $appBin.FullName
                $progCmds += "program_esp {$p} 0x10000 verify exit"
            }
        }

    }
    elseif ($name -match 'rp20|rp23|rp') {
        $elf = Find-Elf $buildDir
        if (-not $elf) { Fail "No .elf found in $buildDir for RP template." }
        Write-Host "[flash] ELF: $($elf.FullName)" -ForegroundColor Cyan
        $p = Format-OcdPath $elf.FullName
        $progCmds += "program {$p} verify reset exit"

    }
    elseif ($name -match 'stm32') {
        $elf = Find-Elf $buildDir
        if (-not $elf) { Fail "No .elf found in $buildDir for STM32 template." }
        Write-Host "[flash] ELF: $($elf.FullName)" -ForegroundColor Cyan
        $p = Format-OcdPath $elf.FullName
        $progCmds += "init; reset halt; program {$p} verify reset exit"

    }
    elseif ($name -match 'nrf') {
        # Zephyr builds produce zephyr.elf under build/zephyr/
        $elf = Find-Elf $buildDir
        if (-not $elf) { Fail "No .elf found in $buildDir for nRF template." }
        Write-Host "[flash] ELF: $($elf.FullName)" -ForegroundColor Cyan
        $p = Format-OcdPath $elf.FullName
        $progCmds += "program {$p} verify reset exit"

    }
    else {
        # Generic fallback: prefer .elf; fall back to largest .bin
        $elf = Find-Elf $buildDir
        if ($elf) {
            Write-Host "[flash] Fallback ELF: $($elf.FullName)" -ForegroundColor Yellow
            $p = Format-OcdPath $elf.FullName
            $progCmds += "program {$p} verify reset exit"
        }
        else {
            Fail "Cannot determine flash strategy for template '$templateName'. Build the project first."
        }
    }

    foreach ($c in $progCmds) { $ocdArgs += '-c', $c }

    Write-Host ""
    Write-OcdCmd $env:OPENOCD_EXE $ocdArgs
    Write-Host ""
    if (-not $NoExec) {
        & $env:OPENOCD_EXE @ocdArgs
    }
    else {
        Write-Host "[flash] Dry-run: skipping OpenOCD execution." -ForegroundColor Yellow
    }
}
finally {
    Clear-OcdEnv
}

