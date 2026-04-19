# Setup Guide

How to build firmware for each platform. For flashing and debugging, see [OpenOCD_guide.md](OpenOCD_guide.md).

## Contents

- [Environment Overview](#environment-overview)
- [Initial Setup](#initial-setup)
- [ESP32 Family (ESP-IDF)](#esp32-family-esp-idf)
- [Raspberry Pi Pico (RP2040/RP2350)](#raspberry-pi-pico-rp2040rp2350)
- [STM32 (ARM Cortex-M)](#stm32-arm-cortex-m)
- [nRF52840 (Zephyr)](#nrf52840-zephyr)
- [Arduino (ESP8266 / Uno)](#arduino-esp8266--uno)
- [Troubleshooting](#troubleshooting)

---

## Environment Overview

All building happens inside a Docker container (Ubuntu 24.04). The container image is about 26 GB and includes these toolchains:

| Toolchain                     | Version      | Location                     |
| ----------------------------- | ------------ | ---------------------------- |
| ESP-IDF                       | release/v6.0 | `/opt/esp/idf`               |
| Pico SDK                      | 2.2.0        | `/opt/pico-sdk`              |
| Zephyr RTOS                   | v4.2.2       | `/opt/zephyrproject/zephyr`  |
| Zephyr SDK                    | 0.17.4       | `/opt/zephyr-sdk-0.17.4`     |
| ARM GCC (`arm-none-eabi-gcc`) | system       | `PATH`                       |
| Arduino CLI                   | 1.4.1        | `/usr/local/bin/arduino-cli` |
| CMake / Ninja / Make          | system       | `PATH`                       |
| west (Zephyr meta-tool)       | latest       | `PATH`                       |

Environment variables are already set:

| Variable                 | Value                       |
| ------------------------ | --------------------------- |
| `IDF_PATH`               | `/opt/esp/idf`              |
| `IDF_TOOLS_PATH`         | `/opt/esp`                  |
| `PICO_SDK_PATH`          | `/opt/pico-sdk`             |
| `ZEPHYR_BASE`            | `/opt/zephyrproject/zephyr` |
| `ZEPHYR_SDK_INSTALL_DIR` | `/opt/zephyr-sdk-0.17.4`    |

Flashing and debugging run on Windows with direct USB access. The container only builds firmware.

---

## Initial Setup

### 1. Get the Container Image

**Option A: Pull from DockerHub** (recommended, faster):

```powershell
docker pull asuracodes/mcu-lab:base
```

**Option B: Build locally** (if you want to modify the Dockerfile):

```powershell
.\scripts\build-base-image.ps1
```

Either way, the image is tagged as `asuracodes/mcu-lab:base`.

### 2. Open the DevContainer Workspace

1. Open `DevContainer.code-workspace` in VS Code
2. Press `F1` → **Dev Containers: Reopen in Container**
3. Wait for VS Code to connect (first time takes a minute)

### 3. Verify Toolchains

Open a terminal in the container:

```bash
# ESP-IDF (needs activation first)
get_idf
idf.py --version

# Pico SDK
echo $PICO_SDK_PATH

# Zephyr
echo $ZEPHYR_BASE
west --version

# ARM GCC
arm-none-eabi-gcc --version

# Arduino CLI
arduino-cli version
```

If these commands work, you're ready to build.

---

## ESP32 Family (ESP-IDF)

Covers: `esp32`, `esp32-wroom32`, `esp32-c3`, `esp32-c6`, `esp32-s2`, `esp32-s3`

ESP8266 uses Arduino CLI instead (see [Arduino section](#arduino-esp8266--uno)).

### Activate ESP-IDF

ESP-IDF tools aren't on PATH by default. Activate them once per terminal session:

```bash
get_idf
# or: source /opt/esp/idf/export.sh
```

The `get_idf` alias is shorter and does the same thing.

### Build

```bash
cd templates/esp32-c3
idf.py set-target esp32c3   # first time only
idf.py build
```

Change `esp32c3` to match your chip (`esp32`, `esp32s2`, `esp32s3`, `esp32c6`).

**Build outputs** in `build/`:
- `bootloader/bootloader.bin`
- `partition_table/partition-table.bin`
- `<project>.bin` — application
- `<project>.elf` — debug symbols

### Commands

```bash
idf.py menuconfig       # configure project options
idf.py size             # show binary size
idf.py fullclean        # delete build + sdkconfig
idf.py clean            # delete build artifacts only
```

### Tasks

Each ESP32 template has `.vscode/tasks.json` with build/clean/menuconfig tasks. Or use the workspace task: **Terminal → Run Task → Build All ESP32 Templates**

---

## Raspberry Pi Pico (RP2040/RP2350)

### Build

```bash
cd templates/rp2040       # or rp2350
mkdir build && cd build
cmake ..
make -j$(nproc)
```

**Build outputs** in `build/`:
- `<project>.elf` — debug symbols
- `<project>.uf2` — drag-and-drop to BOOTSEL drive
- `<project>.bin` — raw binary

### Tasks

Each Pico template has `.vscode/tasks.json` with configure/build/clean tasks. Or use: **Terminal → Run Task → Build All Pico Templates**

### Add SDK Libraries

Edit `CMakeLists.txt`:

```cmake
target_link_libraries(rp2040_template
    pico_stdlib
    hardware_spi
    hardware_i2c
    hardware_pwm
)
```

---

## STM32 (ARM Cortex-M)

All STM32 templates use Zephyr RTOS: `stm32f103`, `stm32f411`, `stm32f412`, `stm32g431`, `stm32h503`

### Build

```bash
cd templates/stm32f103
cmake -B build -DBOARD=stm32_min_dev .
cmake --build build -j4
```

Board names:

| Template  | `-DBOARD=`             |
| --------- | ---------------------- |
| stm32f103 | `stm32_min_dev`        |
| stm32f411 | `blackpill_f411ce`     |
| stm32f412 | `nucleo_f412zg`        |
| stm32g431 | `weact_stm32g431_core` |
| stm32h503 | `nucleo_h503rb`        |

**Build outputs** in `build/zephyr/`:
- `zephyr.elf` — debug symbols
- `zephyr.bin` — raw binary

### Tasks

Each STM32 template has `.vscode/tasks.json` with configure/build/menuconfig/clean tasks. Or use: **Terminal → Run Task → Build All STM32 Templates**

---

## nRF52840 (Zephyr)

Targets the Pro Micro nRF52840 board.

### Build

```bash
cd templates/nrf52840
west build -b promicro_nrf52840
```

**Build outputs** in `build/zephyr/`:
- `zephyr.elf` — debug symbols
- `zephyr.hex` — Intel hex for flashing

---

## Arduino (ESP8266 / Uno)

Templates: `esp8266`, `esp8266-d1mini`, `arduino-uno`

Uses the repo-local Arduino CLI. Cores are pre-installed in the container (`esp8266:esp8266`, `arduino:avr`).

### Build

```bash
cd templates/esp8266-d1mini   # or esp8266, arduino-uno
./build.sh
```

**Build outputs** in `build/`: `.elf`, `.bin` (or `.hex` for AVR)

### Tasks

Use: **Terminal → Run Task → Build All Arduino Templates**

---

## Troubleshooting

### `idf.py: command not found`

ESP-IDF isn't on PATH until you activate it:

```bash
get_idf
```

### CMake can't find Pico SDK

Check the environment variable:

```bash
echo $PICO_SDK_PATH   # should show /opt/pico-sdk
```

If it's empty, you're not in the DevContainer. Reopen with **Dev Containers: Reopen in Container**.

### Build fails after changing toolchain

Clean everything:

```bash
# ESP32
idf.py fullclean && idf.py build

# Pico / STM32
rm -rf build
cmake -B build && cmake --build build
```

### Container image is outdated

If you modified the Dockerfile, rebuild:

```powershell
.\scripts\build-base-image.ps1
```

Then in VS Code: **Dev Containers: Rebuild Container**

