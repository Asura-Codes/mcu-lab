# OpenOCD Guide - Flashing and Debugging

This guide explains how the `Windows.code-workspace` tasks and the PowerShell scripts under `scripts/` work together to drive OpenOCD on the Windows host.

**For building projects**, see **[SETUP_GUIDE.md](SETUP_GUIDE.md)**.

## Table of Contents

- [OpenOCD Guide - Flashing and Debugging](#openocd-guide---flashing-and-debugging)
  - [Table of Contents](#table-of-contents)
  - [How It Works](#how-it-works)
  - [OpenOCD Executables — path.ps1](#openocd-executables--pathps1)
  - [Template Selection — template.ps1](#template-selection--templateps1)
  - [Interface and Target Selection — interface.ps1 / target.ps1](#interface-and-target-selection--interfaceps1--targetps1)
  - [Tasks and Scripts](#tasks-and-scripts)
    - [OpenOCD: Start Server](#openocd-start-server)
    - [OpenOCD: Flash (Interactive)](#openocd-flash-interactive)
    - [OpenOCD: Detect Hardware](#openocd-detect-hardware)
    - [OpenOCD: Target Info / Target Info + Select](#openocd-target-info--target-info--select)
  - [Debugging from the DevContainer](#debugging-from-the-devcontainer)
  - [Environment Variables Reference](#environment-variables-reference)
  - [Troubleshooting](#troubleshooting)
    - [Script exits with "OPENOCD\_EXE not set or not found"](#script-exits-with-openocd_exe-not-set-or-not-found)
    - ["No interface configs discovered"](#no-interface-configs-discovered)
    - [GDB "Connection refused" from the container](#gdb-connection-refused-from-the-container)
    - [Detect Hardware finds nothing](#detect-hardware-finds-nothing)
    - [Flash fails for ESP32 with incorrect offsets](#flash-fails-for-esp32-with-incorrect-offsets)

---

## How It Works

OpenOCD must run on the **Windows host** because it requires direct USB access to hardware debuggers. The GDB client inside the Docker DevContainer connects to the OpenOCD server over TCP.

```
Windows host
  ┌──────────────────────────────────────────────────────┐
  │  openocd-server.ps1  ──►  openocd.exe                │
  │       GDB port 3333  ◄──────────────── USB debugger  │
  │   Telnet port 4444                                    │
  └────────────────────┬─────────────────────────────────┘
                       │ TCP localhost:3333
  Docker container     │
  ┌────────────────────▼─────────────────────────────────┐
  │  arm-none-eabi-gdb  /  Cortex-Debug (VS Code)        │
  │  connects to host.docker.internal:3333               │
  └──────────────────────────────────────────────────────┘
```

All tasks in `Windows.code-workspace` delegate to PowerShell scripts in `scripts/`. Most scripts share a common initialisation chain:

```
path.ps1  →  template.ps1  →  interface.ps1 / target.ps1
```

Each script dot-sources the next and communicates through environment variables prefixed with `OPENOCD_`.

---

## OpenOCD Executables — path.ps1

Every script starts by dot-sourcing `path.ps1`. This script searches the `openocd/` directory at the repo root for installed OpenOCD packages and sets two environment variables:

| Variable          | Content                                                                    |
| ----------------- | -------------------------------------------------------------------------- |
| `OPENOCD_EXE`     | Full path to the selected `openocd.exe`                                    |
| `OPENOCD_SCRIPTS` | Full path to the matching `scripts/` folder (interface and target configs) |

**Discovery logic:**

1. Scans `openocd/*/bin/openocd.exe` (xPack and ESP32 layout) and `openocd/*/openocd.exe` (Pico layout).
2. If `OPENOCD_EXE` is already set in the environment, it is respected and the search is skipped.
3. If exactly one executable is found it is used automatically. If multiple are found, the user is prompted to pick one.
4. The scripts directory is resolved to the folder **sibling to the chosen executable** — this prevents cross-package config mismatches (e.g. using ESP32 OpenOCD with xPack scripts).

When the template and interface are known before OpenOCD selection, the scripts auto-prefer the matching bundled package. Interface capability takes priority over template name:

| Condition                                        | Preferred package                 |
| ------------------------------------------------ | --------------------------------- |
| Interface is `jlink.cfg`                         | `openocd/xpack-openocd-0.12.0-7/` |
| Interface is `esp_usb_jtag.cfg` / `esp_ftdi.cfg` | `openocd/openocd-esp32/`          |
| Template is `esp32*` / `esp8266*`                | `openocd/openocd-esp32/`          |
| Template is `rp2040`, `rp2350`, `nrf52840`       | `openocd/pico/`                   |
| Template is `stm32*` or unrecognised             | `openocd/xpack-openocd-0.12.0-7/` |

> **Note**: The Pico bundle (`openocd/pico/`) does not include J-Link adapter support. When using a J-Link with RP2040/RP2350, the interface-priority rule applies and xPack is selected instead.

The bundled packages under `openocd/` are:

| Folder                            | Variant           | Primary use                                   |
| --------------------------------- | ----------------- | --------------------------------------------- |
| `openocd/xpack-openocd-0.12.0-7/` | xPack universal   | STM32, ARM, RP2040+J-Link                     |
| `openocd/openocd-esp32/`          | Espressif fork    | ESP32 family — required for ESP flash drivers |
| `openocd/pico/`                   | Raspberry Pi fork | RP2040/RP2350 with CMSIS-DAP (Picoprobe)      |

---

## Template Selection — template.ps1

After `path.ps1`, scripts that need to know which firmware to flash dot-source `template.ps1`. It sets:

| Variable                | Content                                               |
| ----------------------- | ----------------------------------------------------- |
| `OPENOCD_TEMPLATE_NAME` | Template folder name, e.g. `esp32-c3`                 |
| `OPENOCD_TEMPLATE_PATH` | Absolute path to that template folder                 |
| `OPENOCD_TARGET`        | Deduced OpenOCD target config (if not already set)    |
| `OPENOCD_INTERFACE`     | Deduced OpenOCD interface config (if not already set) |

**Template-to-config mapping** (built into `template.ps1`):

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

If the template is not in the map, or the target/interface configs cannot be found under `OPENOCD_SCRIPTS`, the user is prompted.

---

## Interface and Target Selection — interface.ps1 / target.ps1

These two helper scripts are dot-sourced when an interface or target has not yet been resolved (either from `template.ps1`'s map or from a command-line argument). Both follow the same pattern:

1. List all `.cfg` files found under `$OPENOCD_SCRIPTS/interface/` or `$OPENOCD_SCRIPTS/target/`.
2. Display a numbered menu.
3. Set `OPENOCD_INTERFACE` or `OPENOCD_TARGET` to the chosen filename.

If `OPENOCD_INTERFACE` / `OPENOCD_TARGET` are already set (from `template.ps1` or a previous selection), the prompt is skipped entirely.

---

## Tasks and Scripts

### OpenOCD: Start Server

**Task in `Windows.code-workspace`** → runs `scripts\openocd-server.ps1`

Starts an OpenOCD GDB server and keeps it running in a dedicated terminal panel. This is the prerequisite for debugging from the DevContainer.

**What the script does:**

1. Pre-seeds the template name and applies any interface/target overrides.
2. Dot-sources `path.ps1` → selects `OPENOCD_EXE` and `OPENOCD_SCRIPTS` (template and interface are already known, so package selection is automatic).
3. Dot-sources `template.ps1` → deduces interface and target from the template map if not already set.
4. If interface or target are still unset, dot-sources `interface.ps1` and `target.ps1` for interactive selection.
5. For RP2040/RP2350 targets, prompts for QSPI flash size if `-QspiFlashSize` was not passed, and injects `set FLASHSIZE <hex>` before the target config is loaded.
6. Determines reset strategy from interface/target and builds the OpenOCD command.
7. Runs OpenOCD in the foreground. Exit code is propagated.

Direct usage (non-interactive):

```powershell
.\scripts\openocd-server.ps1 -Template stm32f103 -Interface stlink.cfg
.\scripts\openocd-server.ps1 -Template rp2040 -Interface jlink.cfg -QspiFlashSize 2MB
.\scripts\openocd-server.ps1 -Template stm32f103 -Interface jlink.cfg -AdapterSpeed 4000
```

---

### OpenOCD: Flash (Interactive)

**Task in `Windows.code-workspace`** → runs `scripts\openocd-flash.ps1`

The task passes two inputs from VS Code: `${input:adapterSpeed}` and `${input:connectUnderReset}`.

**What the script does:**

1. `path.ps1` → executable and scripts path.
2. `template.ps1` → template selection and config deduction.
3. `interface.ps1` / `target.ps1` → if configs still unresolved.
4. Scans `templates/<name>/build/` recursively for `.bin` and `.elf` files.
5. Uses filename heuristics to classify files:
   - `bootloader*.bin` → bootloader
   - `partition[-_]table*.bin` → partition table
   - remaining `.bin` → application (largest file wins on ties)
6. Copies matched files to a temporary staging directory under `scripts/` to avoid path quoting issues.
7. Constructs OpenOCD `-c` commands based on the template family:

   **ESP32 family** — uses `program_esp` with fixed flash offsets:
   - Bootloader: `0x0` (ESP32-C3) or `0x1000` (all others)
   - Partition table: `0x8000`
   - Application: `0x10000`

   **RP2040 / RP2350** — uses `program <file>.elf verify reset exit`

   **STM32** — uses `program <file>.elf verify reset exit`

8. Runs OpenOCD with the assembled arguments.
9. Cleans up the staging directory (unless `-KeepStaged` is passed).

For RP2040 and RP2350, the helper layer also avoids forcing adapter-level `SRST` when using J-Link because those target scripts rely on `SYSRESETREQ` and explicitly note that `SRST` is not available.

Reset strategy is determined automatically from the interface and target:

| Condition                                 | `reset_config` applied                      |
| ----------------------------------------- | ------------------------------------------- |
| Target is `rp2040.cfg` or `rp2350.cfg`    | `none` (SYSRESETREQ; NRST not connected)    |
| Target is `stm32f1x.cfg` + J-Link/ST-Link | `srst_only srst_nogate connect_assert_srst` |
| J-Link, ST-Link, or CMSIS-DAP (other)     | `srst_only srst_nogate`                     |
| `esp_usb_jtag.cfg`                        | `srst_nogate`                               |
| FTDI-based                                | `srst_only srst_nogate connect_assert_srst` |
| Other / unknown                           | `none`                                      |

**`-KeepOpenOCD`**: omits the trailing `exit` command so OpenOCD stays alive after flashing, allowing an immediate debugger attach.

---

### OpenOCD: Detect Hardware

**Task in `Windows.code-workspace`** → runs `scripts\openocd-detect.ps1`

Probes which debug adapters are physically connected by trying interface configs one by one.

**What the script does:**

1. `path.ps1` → executable and scripts path.
2. Builds a list of candidate interface configs from `$OPENOCD_SCRIPTS/interface/` (all `.cfg` files, recursively). Any preferred interfaces (via `$env:OPENOCD_PREFERRED_INTERFACES`) are tried first.
3. For each interface config, runs a short-lived OpenOCD instance:
   ```
   openocd -s <scripts> -f interface/<cfg> -c "adapter speed 1000" -c "init" -c "exit"
   ```
4. Captures stdout+stderr and checks it against positive patterns (`JTAG tap`, `target halted`, `Connected to`, etc.) and negative patterns (`unable to find`, `libusb error`, etc.).
5. Reports which interfaces produced a positive response — i.e. a device was actually found.

This is useful when you don't know which interface config to use for a connected adapter.

---

### OpenOCD: Target Info / Target Info + Select

**Task in `Windows.code-workspace`** → runs `scripts\openocd-info.ps1` (with or without `-SelectTarget`)

Identifies the connected MCU from JTAG IDs.

**What the script does:**

1. `path.ps1` → executable and scripts path.
2. `interface.ps1` → prompts for interface config.
3. Runs OpenOCD with `init`, `targets`, `exit`:
   ```
   openocd -s <scripts> -f interface/<cfg> -c "adapter speed 1000" -c "init" -c "targets" -c "exit"
   ```
4. Parses the output for JTAG ID patterns.
5. Maps detected IDs to known target configs:

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

6. **With `-SelectTarget`**: presents the suggested configs in a menu and sets `OPENOCD_TARGET` to the chosen one, so subsequent scripts (e.g. `openocd-server.ps1`) skip their own target prompt.

---

## Debugging from the DevContainer

1. In `Windows.code-workspace`, run the **OpenOCD: Start Server** task. Leave the terminal open — OpenOCD must stay running.
2. In `DevContainer.code-workspace`, press **F5** and pick the matching launch configuration.

All launch configurations in `DevContainer.code-workspace` use `"servertype": "external"` and connect to `host.docker.internal:3333`. No GDB server is started by VS Code — it simply attaches to the already-running OpenOCD process.

GDB paths per architecture:

| Platform              | GDB binary                                |
| --------------------- | ----------------------------------------- |
| STM32, RP2040, RP2350 | `arm-none-eabi-gdb`                       |
| ESP32, ESP32-S2/S3    | `xtensa-esp32-elf-gdb` (variant-specific) |
| ESP32-C3, ESP32-C6    | `riscv32-esp-elf-gdb`                     |

---

## Environment Variables Reference

These variables are used by the scripts to share state and can be pre-set to skip interactive prompts:

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

Pre-setting these avoids all interactive prompts. For example:

```powershell
$env:OPENOCD_TEMPLATE_NAME = 'stm32f103'
.\scripts\openocd-server.ps1
```

---

## Troubleshooting

### Script exits with "OPENOCD_EXE not set or not found"

`path.ps1` could not find any `openocd.exe` under `openocd/`. Run the **Install Windows Tools** task first to download and extract the bundled OpenOCD packages, or set `OPENOCD_EXE` manually:

```powershell
$env:OPENOCD_EXE = 'C:\path\to\openocd.exe'
```

### "No interface configs discovered"

`OPENOCD_SCRIPTS` does not point to a valid scripts directory or the directory structure is unexpected. Check which package was selected by `path.ps1` and verify the `share\openocd\scripts\interface\` folder exists.

### GDB "Connection refused" from the container

OpenOCD is not running, or is running on a different port. Verify:

```powershell
# On Windows host
netstat -an | findstr 3333
# Should show: TCP  0.0.0.0:3333  LISTENING
```

If the firewall blocks it, allow `openocd.exe` through Windows Defender Firewall for private networks.

### Detect Hardware finds nothing

The adapter USB driver may not be installed:
- **ST-Link**: install ST-Link drivers from ST's website
- **J-Link** (clone): run Zadig, select the J-Link device, install **WinUSB** driver
- **ESP-PROG**: uses an FTDI FT2232H chip — install FTDI VCP/D2XX drivers; no Zadig needed
- **J-Link**: install the J-Link Software Pack from Segger

### Flash fails for ESP32 with incorrect offsets

The script uses fixed offsets (`0x1000` for bootloader on most ESP32, `0x0` for ESP32-C3). If your project uses a custom partition table with different offsets, use the **Flash: ESP32 via esptool.py** task instead, which reads offsets directly from the build's `flash_args` file.

