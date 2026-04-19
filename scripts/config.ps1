<#
Shared OpenOCD configuration: template maps, JTAG table, and utility functions.
Dot-source this in every OpenOCD helper script:

    . "$PSScriptRoot\config.ps1"

All scripts communicate through these environment variables:
  OPENOCD_EXE            Full path to the selected openocd.exe
  OPENOCD_SCRIPTS        Full path to the OpenOCD scripts directory
  OPENOCD_TEMPLATE_NAME  Selected template folder name (e.g. stm32f103)
  OPENOCD_TEMPLATE_PATH  Full path to the template folder
  OPENOCD_INTERFACE      Interface config (e.g. stlink.cfg)    — overrides map default
  OPENOCD_TARGET         Target config   (e.g. stm32f1x.cfg)  — overrides map default
  OPENOCD_TRANSPORT      Transport protocol (swd|jtag)         — auto-inferred if unset
#>

# ---------------------------------------------------------------------------
# Template → default OpenOCD target config.
# Covers every template folder under /templates/. The deduction logic verifies
# the file exists in OPENOCD_SCRIPTS/target/ before applying it; unmapped or
# missing entries fall through to interactive selection in target.ps1.
#   stm32h503 → stm32h5x.cfg  available in OpenOCD ≥ 0.13; not in bundled packages
# ---------------------------------------------------------------------------
$OcdTargetMap = @{
    'esp32'          = 'esp32.cfg'
    'esp32-wroom32'  = 'esp32.cfg'
    'esp32-c3'       = 'esp32c3.cfg'
    'esp32-c6'       = 'esp32c6.cfg'
    'esp32-s2'       = 'esp32s2.cfg'
    'esp32-s3'       = 'esp32s3.cfg'
    'esp8266'        = 'esp8266.cfg'
    'esp8266-d1mini' = 'esp8266.cfg'
    'nrf52840'       = 'nordic/nrf52.cfg'
    'rp2040'         = 'rp2040.cfg'
    'rp2350'         = 'rp2350.cfg'
    'stm32f103'      = 'stm32f1x.cfg'
    'stm32f411'      = 'stm32f4x.cfg'
    'stm32f412'      = 'stm32f4x.cfg'
    'stm32g431'      = 'stm32g4x.cfg'
    'stm32h503'      = 'stm32h5x.cfg'
    # arduino-uno uses AVR — not supported by OpenOCD; flash via avrdude/arduino-cli
}

# ---------------------------------------------------------------------------
# Template → default OpenOCD interface config.
# These are starting-point defaults — override at runtime via:
#   -Interface <name>           script parameter (pass 'auto' to use map default)
#   OPENOCD_INTERFACE=<name>    environment variable set before running a task
#
# Common overrides:
#   ARM/Cortex :  stlink.cfg  ↔  jlink.cfg  ↔  cmsis-dap.cfg
#   ESP32      :  esp_usb_jtag.cfg  ↔  ftdi/esp_ftdi.cfg
# ---------------------------------------------------------------------------
$OcdInterfaceMap = @{
    'esp32'          = 'ftdi/esp_ftdi.cfg'    # FTDI-based JTAG (ESP-PROG or custom board)
    'esp32-wroom32'  = 'ftdi/esp_ftdi.cfg'
    'esp32-c3'       = 'esp_usb_jtag.cfg'     # Built-in USB JTAG on C3/C6/S3
    'esp32-c6'       = 'esp_usb_jtag.cfg'
    'esp32-s2'       = 'ftdi/esp_ftdi.cfg'
    'esp32-s3'       = 'esp_usb_jtag.cfg'
    'esp8266'        = 'esp_usb_jtag.cfg'
    'esp8266-d1mini' = 'esp_usb_jtag.cfg'
    'nrf52840'       = 'jlink.cfg'            # nRF52840-DK has on-board J-Link
    'rp2040'         = 'jlink.cfg'
    'rp2350'         = 'jlink.cfg'
    'stm32f103'      = 'jlink.cfg'
    'stm32f411'      = 'jlink.cfg'
    'stm32f412'      = 'jlink.cfg'
    'stm32g431'      = 'jlink.cfg'
    'stm32h503'      = 'jlink.cfg'
}

# ---------------------------------------------------------------------------
# Per-interface target probing order.
# Used by openocd-detect.ps1 and openocd-info.ps1 to auto-discover the chip
# after an adapter is found.  Keys are the base filename of the interface
# config (without path or extension).  Variants like stlink-v2.cfg match via
# prefix (Get-OcdProbeTargets handles the lookup).
# ---------------------------------------------------------------------------
$OcdProbeTargets = @{
    stlink        = @('stm32f1x.cfg', 'stm32f4x.cfg', 'stm32g4x.cfg', 'stm32l4x.cfg', 'stm32f7x.cfg', 'stm32h7x.cfg', 'stm32f0x.cfg', 'stm32f3x.cfg', 'stm32l5x.cfg')
    jlink         = @('stm32f1x.cfg', 'stm32f4x.cfg', 'stm32g4x.cfg', 'nordic/nrf52.cfg', 'rp2040.cfg', 'rp2350.cfg')
    'cmsis-dap'   = @('rp2040.cfg', 'rp2350.cfg', 'stm32f4x.cfg', 'nordic/nrf52.cfg')
    esp_usb_jtag  = @('esp32c3.cfg', 'esp32c6.cfg', 'esp32s3.cfg', 'esp32s2.cfg', 'esp32.cfg')
    esp_ftdi      = @('esp32.cfg', 'esp32s2.cfg', 'esp32s3.cfg')
    esp_gpio_jtag = @('esp32.cfg', 'esp32s2.cfg', 'esp32s3.cfg')
}

# Return the probe-target list for a given interface config filename.
# Tries an exact base-name match first, then a prefix match so that
# stlink-v2.cfg, stlink-v2-1.cfg, etc. all resolve to stlink's list.
function Get-OcdProbeTargets([string]$iface) {
    $n = [IO.Path]::GetFileNameWithoutExtension($iface).ToLower()
    if ($OcdProbeTargets.ContainsKey($n)) { return $OcdProbeTargets[$n] }
    foreach ($k in ($OcdProbeTargets.Keys | Sort-Object { $_.Length } -Descending)) {
        if ($n.StartsWith($k)) { return $OcdProbeTargets[$k] }
    }
    return @()
}

# ---------------------------------------------------------------------------
# Utility functions
# ---------------------------------------------------------------------------

# Infer OpenOCD transport (swd|jtag) from an interface filename.
# Returns '' when the interface name gives no clear indication.
function Get-OcdTransport([string]$iface) {
    $n = [IO.Path]::GetFileName($iface)
    if ($n -match '(?i)stlink|jlink|cmsis-dap') { return 'swd' }
    if ($n -match '(?i)ftdi|usb-jtag|ti-icdi') { return 'jtag' }
    return ''
}

# Ensure a config filename ends with .cfg.
function Add-CfgExt([string]$name) {
    if ($name -and -not $name.ToLower().EndsWith('.cfg')) { "$name.cfg" } else { $name }
}

# Normalize a path to forward-slashes for use in OpenOCD -c command strings.
function Format-OcdPath([string]$p) { $p.Replace('\', '/') }

# Build the base OpenOCD argument array: scripts dir, interface (with transport),
# optional pre-target commands, then target.
# Callers append further -c commands after calling this function.
function Build-OcdArgs([string]$scripts, [string]$iface, [string]$target, [string[]]$preTargetCommands = @()) {
    $a = @('-s', $scripts)
    if ($iface) {
        $a += '-f', "interface/$iface"
        $t = if ($env:OPENOCD_TRANSPORT) { $env:OPENOCD_TRANSPORT } else { Get-OcdTransport $iface }
        if ($t) { $a += '-c', "transport select $t" }
    }
    if ($preTargetCommands) {
        foreach ($cmd in $preTargetCommands) {
            if ($cmd) { $a += '-c', $cmd }
        }
    }
    if ($target) { $a += '-f', "target/$target" }
    return $a
}

# Print the full OpenOCD command being executed for transparency.
function Write-OcdCmd([string]$exe, [array]$ocdArgs) {
    Write-Host "  [cmd] $exe $($ocdArgs -join ' ')" -ForegroundColor DarkGray
}

# Find the most recently written .elf under a build directory (including build/zephyr/).
function Find-Elf([string]$buildDir) {
    @(
        Get-ChildItem -Path $buildDir -File -Filter '*.elf' -ErrorAction SilentlyContinue
        if (Test-Path "$buildDir\zephyr") {
            Get-ChildItem -Path "$buildDir\zephyr" -File -Filter '*.elf' -ErrorAction SilentlyContinue
        }
    ) | Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

# Remove all OPENOCD_* environment variables to prevent state leakage between runs.
function Clear-OcdEnv {
    @('OPENOCD_EXE', 'OPENOCD_SCRIPTS', 'OPENOCD_INTERFACE', 'OPENOCD_TARGET',
        'OPENOCD_TRANSPORT', 'OPENOCD_TEMPLATE_NAME', 'OPENOCD_TEMPLATE_PATH') |
    ForEach-Object { Remove-Item "Env:$_" -ErrorAction SilentlyContinue }
}
