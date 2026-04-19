# OpenOCD Guide

How the Windows tasks and PowerShell scripts work together to flash and debug firmware. For building, see [SETUP_GUIDE.md](SETUP_GUIDE.md).

## Contents

- [OpenOCD Guide](#openocd-guide)
  - [Contents](#contents)
  - [How It Works](#how-it-works)
  - [OpenOCD Executables — path.ps1](#openocd-executables--pathps1)
  - [Template Selection — template.ps1](#template-selection--templateps1)
  - [Interface and Target Selection — interface.ps1 / target.ps1](#interface-and-target-selection--interfaceps1--targetps1)
  - [Tasks and Scripts](#tasks-and-scripts)
    - [OpenOCD: Start Server](#openocd-start-server)
    - [OpenOCD: Flash (Interactive)](#openocd-flash-interactive)
    - [OpenOCD: Detect Hardware](#openocd-detect-hardware)
    - [OpenOCD: Target Info](#openocd-target-info)
  - [Debugging from the Container](#debugging-from-the-container)
  - [Environment Variables](#environment-variables)
  - [Troubleshooting](#troubleshooting)
    - [Script exits with "OPENOCD\_EXE not set or not found"](#script-exits-with-openocd_exe-not-set-or-not-found)
    - ["No interface configs discovered"](#no-interface-configs-discovered)
    - [GDB "Connection refused" from container](#gdb-connection-refused-from-container)
    - [Detect Hardware finds nothing](#detect-hardware-finds-nothing)
    - [Flash fails for ESP32 with wrong offsets](#flash-fails-for-esp32-with-wrong-offsets)

---

## How It Works

OpenOCD runs on Windows because it needs direct USB access to debug adapters. USB passthrough to Docker on Windows isn't reliable enough. The GDB client in the container connects to OpenOCD over TCP.

```
Windows host
  ┌──────────────────────────────────────────────────────┐
  │  openocd-server.ps1  ──►  openocd.exe                │
  │       GDB port 3333  ◄──────────────── USB debugger  │
  │   Telnet port 4444                                   │
  └────────────────────┬─────────────────────────────────┘
                       │ TCP localhost:3333
  Docker container     │
  ┌────────────────────▼─────────────────────────────────┐
  │  arm-none-eabi-gdb  /  Cortex-Debug (VS Code)        │
  │  connects to host.docker.internal:3333               │
  └──────────────────────────────────────────────────────┘
```

Tasks in `Windows.code-workspace` run PowerShell scripts from `scripts/`. Most scripts follow this chain:

```
path.ps1  →  template.ps1  →  interface.ps1 / target.ps1
```

Scripts communicate through environment variables (all prefixed with `OPENOCD_`).

---

## OpenOCD Executables — path.ps1

All scripts start by running `path.ps1`, which searches `openocd/` for installed OpenOCD packages and sets:

| Variable          | Content                                                                    |
| ----------------- | -------------------------------------------------------------------------- |
| `OPENOCD_EXE`     | Full path to the selected `openocd.exe`                                    |
| `OPENOCD_SCRIPTS` | Full path to the matching `scripts/` folder (interface and target configs) |

**How it finds OpenOCD:**

1. Scans for `openocd.exe` in `openocd/*/bin/` (xPack/ESP32) and `openocd/*/` (Pico)
2. If `OPENOCD_EXE` is already set, uses that and skips searching
3. If one executable found, uses it automatically. If multiple found, prompts you to choose
4. Finds the scripts directory next to the executable (prevents config mismatches)

When the template and interface are known, scripts auto-select the best OpenOCD package. Interface type wins over template name:

| Condition                                        | Preferred package                 |
| ------------------------------------------------ | --------------------------------- |
| Interface is `jlink.cfg`                         | `openocd/xpack-openocd-0.12.0-7/` |
| Interface is `esp_usb_jtag.cfg` / `esp_ftdi.cfg` | `openocd/openocd-esp32/`          |
| Template is `esp32*` / `esp8266*`                | `openocd/openocd-esp32/`          |
| Template is `rp2040`, `rp2350`, `nrf52840`       | `openocd/pico/`                   |
| Template is `stm32*` or unrecognised             | `openocd/xpack-openocd-0.12.0-7/` |

**Note:** The Pico OpenOCD doesn't support J-Link. If you use J-Link with RP2040/RP2350, xPack is selected instead.

Available OpenOCD packages:

| Folder                            | Variant           | Primary use                                   |
| --------------------------------- | ----------------- | --------------------------------------------- |
| `openocd/xpack-openocd-0.12.0-7/` | xPack universal   | STM32, ARM, RP2040+J-Link                     |
| `openocd/openocd-esp32/`          | Espressif fork    | ESP32 family — required for ESP flash drivers |
| `openocd/pico/`                   | Raspberry Pi fork | RP2040/RP2350 with CMSIS-DAP (Picoprobe)      |

---

## Template Selection — template.ps1

Scripts that need to know which firmware to flash run `template.ps1`. It sets:

| Variable                | Content                                               |
| ----------------------- | ----------------------------------------------------- |
| `OPENOCD_TEMPLATE_NAME` | Template folder name, e.g. `esp32-c3`                 |
| `OPENOCD_TEMPLATE_PATH` | Absolute path to that template folder                 |
| `OPENOCD_TARGET`        | Deduced OpenOCD target config (if not already set)    |
| `OPENOCD_INTERFACE`     | Deduced OpenOCD interface config (if not already set) |

**Template-to-config mapping:**

| Template         | Target config  | Default interface   |
| ---------------- | -------------- | ------------------- |
| `esp32`          | `esp32.cfg`    | `ftdi/esp_ftdi.cfg` |
| `esp32-wroom32`  | `esp32.cfg`    | `ftdi/esp_ftdi.cfg` |
| `esp32-c3`       | `esp32c3.cfg`  | `esp_usb_jtag.cfg`  |
| `esp32-c6`       | `esp32c6.cfg`  | `esp_usb_jtag.cfg`  |
| `esp32-s2`       | `esp32s2.cfg`  | `ftdi/esp_ftdi.cfg` |
| `esp32-s3`       | `esp32s3.cfg`  | `esp_usb_jtag.cfg`  |
| `esp8266`        | `esp8266.cfg`  | `esp_usb_jtag.cfg`  |
| `esp8266-d1mini` | `esp8266.cfg`  | `esp_usb_jtag.cfg`  |
| `nrf52840`       | `nrf52.cfg`    | `jlink.cfg`         |
| `rp2040`         | `rp2040.cfg`   | `jlink.cfg`         |
| `rp2350`         | `rp2350.cfg`   | `jlink.cfg`         |
| `stm32f103`      | `stm32f1x.cfg` | `jlink.cfg`         |
| `stm32f411`      | `stm32f4x.cfg` | `jlink.cfg`         |
| `stm32f412`      | `stm32f4x.cfg` | `jlink.cfg`         |
| `stm32g431`      | `stm32g4x.cfg` | `jlink.cfg`         |
| `stm32h503`      | `stm32h5x.cfg` | `jlink.cfg`         |

If the template isn't in the map, or configs aren't found, you'll be prompted to select one.

---

## Interface and Target Selection — interface.ps1 / target.ps1

These scripts run when the interface or target hasn't been resolved yet. They:

1. List all `.cfg` files in `$OPENOCD_SCRIPTS/interface/` or `$OPENOCD_SCRIPTS/target/`
2. Show a numbered menu
3. Set `OPENOCD_INTERFACE` or `OPENOCD_TARGET` to your choice

If these variables are already set, the prompt is skipped.

---

## Tasks and Scripts

### OpenOCD: Start Server

**Task:** `Windows.code-workspace` → runs `scripts\openocd-server.ps1`

Starts OpenOCD GDB server and keeps it running. Required for debugging from the container.

**What it does:**

1. Loads template name and any interface/target overrides
2. Runs `path.ps1` → finds OpenOCD executable and scripts
3. Runs `template.ps1` → figures out interface and target configs
4. If still missing, runs `interface.ps1` and `target.ps1` for interactive selection
5. For RP2040/RP2350, prompts for QSPI flash size if not specified
6. Determines reset strategy from interface/target
7. Runs OpenOCD and shows output

Direct usage (non-interactive):

```powershell
.\scripts\openocd-server.ps1 -Template stm32f103 -Interface stlink.cfg
.\scripts\openocd-server.ps1 -Template rp2040 -Interface jlink.cfg -QspiFlashSize 2MB
.\scripts\openocd-server.ps1 -Template stm32f103 -Interface jlink.cfg -AdapterSpeed 4000
```

---

### OpenOCD: Flash (Interactive)

**Task:** `Windows.code-workspace` → runs `scripts\openocd-flash.ps1`

Flashes firmware to the chip. VS Code prompts for adapter speed and reset options.

**What it does:**

1. Runs `path.ps1` → finds OpenOCD
2. Runs `template.ps1` → selects template and configs
3. Runs `interface.ps1` / `target.ps1` → if needed
4. Searches `templates/<name>/build/` for `.bin` and `.elf` files
5. Classifies files by name:
   - `bootloader*.bin` → bootloader
   - `partition[-_]table*.bin` → partition table
   - other `.bin` → application (picks largest if multiple)
6. Copies files to temp staging directory (avoids path quoting issues)
7. Builds OpenOCD flash commands based on platform:

   **ESP32 family** — uses `program_esp` with fixed flash offsets:
   - Bootloader: `0x0` (ESP32-C3) or `0x1000` (all others)
   - Partition table: `0x8000`
   - Application: `0x10000`

   **RP2040 / RP2350** — uses `program <file>.elf verify reset exit`

   **STM32** — uses `program <file>.elf verify reset exit`

8. Runs OpenOCD with the flash commands
9. Cleans up staging directory (unless you pass `-KeepStaged`)

For RP2040/RP2350, the script doesn't use hardware reset (`SRST`) with J-Link because the Pico doesn't have that pin connected. It uses software reset (`SYSRESETREQ`) instead.

Reset strategy is picked automatically:

| Condition                                 | `reset_config` applied                      |
| ----------------------------------------- | ------------------------------------------- |
| Target is `rp2040.cfg` or `rp2350.cfg`    | `none` (SYSRESETREQ; NRST not connected)    |
| Target is `stm32f1x.cfg` + J-Link/ST-Link | `srst_only srst_nogate connect_assert_srst` |
| J-Link, ST-Link, or CMSIS-DAP (other)     | `srst_only srst_nogate`                     |
| `esp_usb_jtag.cfg`                        | `srst_nogate`                               |
| FTDI-based                                | `srst_only srst_nogate connect_assert_srst` |
| Other / unknown                           | `none`                                      |

**`-KeepOpenOCD`**: Leaves OpenOCD running after flash so you can attach a debugger immediately.

---

### OpenOCD: Detect Hardware

**Task:** `Windows.code-workspace` → runs `scripts\openocd-detect.ps1`

Figures out which debug adapters are connected by trying interface configs.

**What it does:**

1. Runs `path.ps1` → finds OpenOCD
2. Lists all interface configs from `$OPENOCD_SCRIPTS/interface/`. Tries preferred interfaces first if you set `$env:OPENOCD_PREFERRED_INTERFACES`
3. For each config, runs a quick OpenOCD test:
   ```
   openocd -s <scripts> -f interface/<cfg> -c "adapter speed 1000" -c "init" -c "exit"
   ```
4. Checks output for success patterns (`JTAG tap`, `target halted`, etc.) and failure patterns (`unable to find`, `libusb error`, etc.)
5. Reports which interfaces found a device

Useful when you don't know which config matches your debug adapter.

---

### OpenOCD: Target Info

**Task:** `Windows.code-workspace` → runs `scripts\openocd-info.ps1`

Reads the chip's JTAG ID and suggests the correct target config.

**What it does:**

1. Runs `path.ps1` → finds OpenOCD
2. Runs `interface.ps1` → prompts for interface
3. Runs OpenOCD to read JTAG IDs:
   ```
   openocd -s <scripts> -f interface/<cfg> -c "adapter speed 1000" -c "init" -c "targets" -c "exit"
   ```
4. Parses output for JTAG IDs
5. Maps IDs to target configs:

   | JTAG ID      | Suggested target |
   | ------------ | ---------------- |
   | `0x120034e5` | `esp32.cfg`      |
   | `0x00005c25` | `esp32s2.cfg`    |
   | `0x120034e3` | `esp32s3.cfg`    |
   | `0x6921506f` | `esp32c3.cfg`    |
   | `0x2b000000` | `rp2040.cfg`     |
   | `0x6ba02477` | `rp2350.cfg`     |
   | `0x3ba00477` | `stm32f1x.cfg`   |
   | `0x4ba00477` | `stm32f4x.cfg`   |

6. **With `-SelectTarget`**: Shows a menu of suggested configs and sets `OPENOCD_TARGET` so other scripts don't prompt again.

---

## Debugging from the Container

1. In `Windows.code-workspace`: Run **OpenOCD: Start Server**. Leave it running.
2. In `DevContainer.code-workspace`: Press **F5** and choose your debug config.

The container's GDB connects to `host.docker.internal:3333`. VS Code doesn't start its own GDB server — it attaches to the OpenOCD already running on Windows.

GDB binaries used:

| Platform           | GDB binary                                |
| ------------------ | ----------------------------------------- |
| STM32, nRF52840    | `arm-zephyr-eabi-gdb`                     |
| RP2040, RP2350     | `gdb-multiarch`                           |
| ESP32, ESP32-S2/S3 | `xtensa-esp32-elf-gdb` (variant-specific) |
| ESP32-C3, ESP32-C6 | `riscv32-esp-elf-gdb`                     |

---

## Environment Variables

Scripts use these to share state. Pre-set them to skip prompts:

| Variable                       | Set by                           | Purpose                                                       |
| ------------------------------ | -------------------------------- | ------------------------------------------------------------- |
| `OPENOCD_EXE`                  | `path.ps1`                       | Full path to `openocd.exe`                                    |
| `OPENOCD_SCRIPTS`              | `path.ps1`                       | Path to OpenOCD scripts directory                             |
| `OPENOCD_TEMPLATE_NAME`        | `template.ps1`                   | Selected template name                                        |
| `OPENOCD_TEMPLATE_PATH`        | `template.ps1`                   | Full path to template folder                                  |
| `OPENOCD_INTERFACE`            | `template.ps1` / `interface.ps1` | Interface config filename                                     |
| `OPENOCD_TARGET`               | `template.ps1` / `target.ps1`    | Target config filename                                        |
| `OPENOCD_ADAPTER_KHZ`          | user / env                       | Adapter speed override (kHz)                                  |
| `OPENOCD_PREFERRED_INTERFACES` | user / env                       | Semicolon-separated list of interfaces to try first in detect |

Example - skip prompts by setting variables:

```powershell
$env:OPENOCD_TEMPLATE_NAME = 'stm32f103'
.\scripts\openocd-server.ps1
```

---

## Troubleshooting

### Script exits with "OPENOCD_EXE not set or not found"

`path.ps1` can't find `openocd.exe` in `openocd/`. Run **Install Windows Tools** task first, or set it manually:

```powershell
$env:OPENOCD_EXE = 'C:\path\to\openocd.exe'
```

### "No interface configs discovered"

`OPENOCD_SCRIPTS` doesn't point to a valid directory. Check which OpenOCD package `path.ps1` selected and verify `share\openocd\scripts\interface\` exists.

### GDB "Connection refused" from container

OpenOCD isn't running or is on the wrong port. Check:

```powershell
# On Windows host
netstat -an | findstr 3333
# Should show: TCP  0.0.0.0:3333  LISTENING
```

If your firewall blocks it, allow `openocd.exe` through Windows Defender Firewall.

### Detect Hardware finds nothing

Missing USB drivers:
- **ST-Link**: Install ST-Link drivers from ST
- **J-Link clone**: Run Zadig, install WinUSB driver
- **ESP-PROG**: Install FTDI drivers (FT2232H chip)
- **J-Link official**: Install J-Link Software Pack from Segger

### Flash fails for ESP32 with wrong offsets

The script uses fixed offsets (bootloader at `0x1000` for most ESP32, `0x0` for ESP32-C3). If you have custom partition offsets, use **Flash: ESP32 via esptool.py** instead — it reads offsets from `build/flash_args`.

