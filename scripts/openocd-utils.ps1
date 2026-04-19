<#
Helper utilities for OpenOCD scripts.

Functions:
  Get-OcdResetConfig - Return reset strategy from local interface/target rules.
  Test-OcdQspiTarget - Return true when the selected OpenOCD target uses QSPI flash sizing.
  Resolve-OcdQspiFlashSize - Resolve a QSPI flash size from a preset menu, with optional prompt.

Usage:
  . "$PSScriptRoot\openocd-utils.ps1"
  $cfg = Get-OcdResetConfig -Interface $env:OPENOCD_INTERFACE -Target $env:OPENOCD_TARGET
  $cfg.ResetConfig  # e.g. 'srst_only srst_nogate' or 'none'
  $cfg.SupportsSrst # $true / $false
#>

function Get-OcdResetConfig {
    param(
        [string]$Interface,
        [string]$Target
    )

    $result = @{
        ResetConfig   = 'srst_only srst_nogate connect_assert_srst'
        SupportsSrst  = $true
        InterfaceBase = $Interface
        TargetBase    = $Target
    }

    if (-not $Interface) { return $result }

    $ifaceBase = [System.IO.Path]::GetFileName($Interface)
    $targetBase = if ($Target) { [System.IO.Path]::GetFileName($Target) } else { '' }
    $result.InterfaceBase = $ifaceBase
    $result.TargetBase = $targetBase

    # RP targets use SYSRESETREQ in target scripts; do not force adapter SRST.
    if ($targetBase -match '^(rp2040|rp2350)\.cfg$') {
        $result.ResetConfig = 'none'
        $result.SupportsSrst = $false
        return $result
    }

    # nRF52 boards commonly rely on SYSRESETREQ/soft reset paths. Forcing
    # adapter SRST can fail when NRST is not wired to the debug probe.
    if ($targetBase -eq 'nrf52.cfg') {
        $result.ResetConfig = 'none'
        $result.SupportsSrst = $false
        return $result
    }

    # Some STM32F1 boards connect more reliably when SRST is asserted during attach.
    if ($targetBase -eq 'stm32f1x.cfg' -and $ifaceBase -match 'jlink|stlink|cmsis-dap') {
        $result.ResetConfig = 'srst_only srst_nogate connect_assert_srst'
        $result.SupportsSrst = $true
        return $result
    }

    if ($ifaceBase -match 'jlink|stlink|cmsis-dap') {
        $result.SupportsSrst = $true
        $result.ResetConfig = 'srst_only srst_nogate'
    }
    elseif ($ifaceBase -match 'esp_usb_jtag') {
        $result.ResetConfig = 'srst_nogate'
        $result.SupportsSrst = $false
    }
    elseif ($ifaceBase -match 'ftdi|ft232|ft223') {
        $result.ResetConfig = 'srst_only srst_nogate connect_assert_srst'
        $result.SupportsSrst = $true
    }
    else {
        $result.ResetConfig = 'none'
        $result.SupportsSrst = $false
    }

    return $result
}

function Test-OcdQspiTarget {
    param([string]$Target)

    $targetBase = if ($Target) { [System.IO.Path]::GetFileName($Target).ToLower() } else { '' }
    return $targetBase -match '^(rp2040|rp2350)\.cfg$'
}

function Get-OcdQspiFlashSizeOptions {
    return @(
        @{ Label = 'Auto-detect'; Value = '0'; IsOverride = $false; Aliases = @('auto', '0', '') }
        @{ Label = '1 MB'; Value = '0x100000'; IsOverride = $true; Aliases = @('1', '1mb', '1048576', '0x100000') }
        @{ Label = '2 MB'; Value = '0x200000'; IsOverride = $true; Aliases = @('2', '2mb', '2097152', '0x200000') }
        @{ Label = '4 MB'; Value = '0x400000'; IsOverride = $true; Aliases = @('4', '4mb', '4194304', '0x400000') }
        @{ Label = '8 MB'; Value = '0x800000'; IsOverride = $true; Aliases = @('8', '8mb', '8388608', '0x800000') }
        @{ Label = '16 MB'; Value = '0x1000000'; IsOverride = $true; Aliases = @('16', '16mb', '16777216', '0x1000000') }
    )
}

function Resolve-OcdQspiFlashSize {
    param(
        [string]$RequestedSize = '',
        [switch]$PromptIfMissing
    )

    $options = Get-OcdQspiFlashSizeOptions
    $requested = if ($null -ne $RequestedSize) { [string]$RequestedSize } else { '' }
    $normalized = $requested.Trim().ToLower().Replace(' ', '')

    if ($normalized) {
        foreach ($opt in $options) {
            if ($opt.Aliases -contains $normalized) { return $opt }
        }
        throw "Unsupported QSPI flash size '$RequestedSize'. Allowed values: auto, 1MB, 2MB, 4MB, 8MB, 16MB."
    }

    if ($PromptIfMissing) {
        Write-Host "QSPI flash size options:" -ForegroundColor Cyan
        for ($i = 0; $i -lt $options.Count; $i++) {
            Write-Host "  [$i] $($options[$i].Label)"
        }
        $s = Read-Host "Select index (default 0)"
        $idx = if ($s -match '^\d+$' -and [int]$s -lt $options.Count) { [int]$s } else { 0 }
        return $options[$idx]
    }

    return $options[0]
}
