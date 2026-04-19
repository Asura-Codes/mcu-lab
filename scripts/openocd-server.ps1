<#
Start an OpenOCD GDB server so the DevContainer debug client can connect.

The server keeps running in the foreground and is stopped with Ctrl-C.
GDB connects on localhost:3333 (or host.docker.internal:3333 from the container).

Parameters:
  -Template      Template name or index — skips the interactive prompt.
                 Determines the default interface and target config via config.ps1 maps.
  -Interface     Interface config name (e.g. stlink.cfg, jlink.cfg).
                 Overrides the template map default. Pass 'auto' to use the map default.
  -Target        Target config name (e.g. stm32f1x.cfg). Overrides the map default.
  -QspiFlashSize QSPI flash size override for RP2040/RP2350 targets with unrecognised flash IDs.
                 Accepted values: auto, 1MB, 2MB, 4MB, 8MB, 16MB. Default: auto (no override).
  -AdapterSpeed  Adapter clock in kHz (default 1000).
  -GdbPort       GDB server port (default 3333).
  -TelnetPort    Telnet control port (default 4444).

Examples:
  .\openocd-server.ps1                                              interactive
  .\openocd-server.ps1 -Template stm32f103                          uses stm32f1x from map
  .\openocd-server.ps1 -Template stm32f103 -Interface jlink.cfg
  .\openocd-server.ps1 -Template rp2040 -Interface jlink.cfg -QspiFlashSize 2MB
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
    [int]   $GdbPort = 3333,
    [int]   $TelnetPort = 4444
)

. "$PSScriptRoot\config.ps1"
. "$PSScriptRoot\openocd-utils.ps1"

try {
    # 1. Pre-seed template so path.ps1 can pick the right OpenOCD package.
    if ($Template -and -not $env:OPENOCD_TEMPLATE_NAME) {
        $dirs = @(Get-ChildItem -Path (Join-Path (Split-Path -Parent $PSScriptRoot) 'templates') -Directory |
            Sort-Object Name)
        $m = if ($Template -match '^\d+$') { $dirs[[int]$Template] } else {
            $dirs | Where-Object { $_.Name -ieq $Template } | Select-Object -First 1
        }
        if ($m) { $env:OPENOCD_TEMPLATE_NAME = $m.Name; $env:OPENOCD_TEMPLATE_PATH = $m.FullName }
    }

    # 2. Apply interface/target overrides before path.ps1 so package selection can use them.
    if ($Interface -and $Interface -ne 'auto') {
        $env:OPENOCD_INTERFACE = Add-CfgExt $Interface
        Write-Host "[server] Interface override: $env:OPENOCD_INTERFACE" -ForegroundColor Cyan
    }
    if ($Target -and $Target -ne 'auto') {
        $env:OPENOCD_TARGET = Add-CfgExt $Target
        Write-Host "[server] Target override: $env:OPENOCD_TARGET" -ForegroundColor Cyan
    }

    # 3. Select OpenOCD executable (template and interface are now known).
    . "$PSScriptRoot\path.ps1" | Out-Null
    if (-not $env:OPENOCD_EXE -or -not (Test-Path $env:OPENOCD_EXE)) {
        Write-Host "[server] OPENOCD_EXE not found. Run path.ps1 first." -ForegroundColor Red; exit 1
    }
    if (-not $env:OPENOCD_SCRIPTS -or -not (Test-Path $env:OPENOCD_SCRIPTS)) {
        Write-Host "[server] OPENOCD_SCRIPTS not found. Run path.ps1 first." -ForegroundColor Red; exit 1
    }

    . "$PSScriptRoot\template.ps1"

    # Fall back to interactive selection when maps gave no result.
    if (-not $env:OPENOCD_INTERFACE) { . "$PSScriptRoot\interface.ps1" }
    if (-not $env:OPENOCD_TARGET) { . "$PSScriptRoot\target.ps1" }

    $templateName = $env:OPENOCD_TEMPLATE_NAME
    $iface = $env:OPENOCD_INTERFACE
    $target = $env:OPENOCD_TARGET

    Write-Host ""
    Write-Host "=== OpenOCD GDB Server ===" -ForegroundColor Green
    Write-Host "  Executable : $env:OPENOCD_EXE"
    Write-Host "  Scripts    : $env:OPENOCD_SCRIPTS"
    Write-Host "  Interface  : $(if ($iface)  { $iface }  else { '(none)' })"
    Write-Host "  Target     : $(if ($target) { $target } else { '(none)' })"
    Write-Host "  Adapter    : $AdapterSpeed kHz"
    Write-Host "  GDB port   : $GdbPort   Telnet port: $TelnetPort"
    Write-Host ""

    # Resolve QSPI flash size for RP2040/RP2350 targets with unrecognised flash IDs.
    $preTargetCmds = @()
    if (Test-OcdQspiTarget -Target $target) {
        $resolvedSize = Resolve-OcdQspiFlashSize -RequestedSize $QspiFlashSize -PromptIfMissing
        if ($resolvedSize.IsOverride) {
            $preTargetCmds += "set FLASHSIZE $($resolvedSize.Value)"
        }
    }

    $ocdArgs = Build-OcdArgs $env:OPENOCD_SCRIPTS $iface $target $preTargetCmds

    if ($VerboseOcd) {
        $ocdArgs += '-d3'  # verbose debug output to help troubleshoot config issues
        Write-Host "[server] OpenOCD verbose logging enabled (-d3)." -ForegroundColor Yellow
    }

    $ocdArgs += '-c', "tcl_port disabled"
    $ocdArgs += '-c', "adapter speed $AdapterSpeed"

    $util = Get-OcdResetConfig -Interface $env:OPENOCD_INTERFACE -Target $target
    $resetCfg = $util.ResetConfig

    $ocdArgs += '-c', "adapter srst pulse_width $SrstPulseWidth"
    $ocdArgs += '-c', "adapter srst delay $SrstDelay"
    $ocdArgs += '-c', "reset_config $resetCfg"
    Write-Host "Reset config determined as: $resetCfg [$SrstDelay ms]" -ForegroundColor Cyan

    if ($templateName -match 'esp') { $ocdArgs += '-c', 'gdb breakpoint_override hard' }
    if ($templateName -match 'c3|c6') { $ocdArgs += '-c', 'riscv set_command_timeout_sec 10' }

    $ocdArgs += '-c', "gdb port $GdbPort"
    $ocdArgs += '-c', "telnet port $TelnetPort"

    $ocdArgs += '-c', 'init'
    $ocdArgs += '-c', 'reset halt'

    Write-OcdCmd $env:OPENOCD_EXE $ocdArgs
    Write-Host ""
    & $env:OPENOCD_EXE @ocdArgs
    exit $LASTEXITCODE
}
finally {
    Clear-OcdEnv
}
