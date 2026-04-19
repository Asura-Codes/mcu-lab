# Setup Guide

This guide covers the development environment and building firmware for each supported platform.

**For flashing and debugging**, see **[OpenOCD_guide.md](OpenOCD_guide.md)**.

## Table of Contents

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

Building runs inside a **Docker DevContainer** (Ubuntu 24.04). The container image bundles all toolchains and is built from `.devcontainer/Dockerfile`. The Windows host handles flashing and debugging via OpenOCD and other host tools.

| Toolchain                     | Version      | Location in container        |
| ----------------------------- | ------------ | ---------------------------- |
| ESP-IDF                       | release/v6.0 | `/opt/esp/idf`               |
| Pico SDK                      | 2.2.0        | `/opt/pico-sdk`              |
| ARM GCC (`arm-none-eabi-gcc`) | system       | `PATH`                       |
| Arduino CLI                   | 1.4.1        | `/usr/local/bin/arduino-cli` |
| CMake / Ninja / Make          | system       | `PATH`                       |

Pre-set environment variables:

| Variable         | Value           |
| ---------------- | --------------- |
| `IDF_PATH`       | `/opt/esp/idf`  |
| `IDF_TOOLS_PATH` | `/opt/esp`      |
| `PICO_SDK_PATH`  | `/opt/pico-sdk` |

---

## Initial Setup

### 1. Build or Pull the Container Image

The container image is built from `.devcontainer/Dockerfile`. Build it with the included script:

```powershell
# Windows host
.\scripts\build-base-image.ps1
```

This tags the image as `asuracodes/mcu-lab:base`. The base image is reused every time you reopen the DevContainer, so you only need to rebuild when the Dockerfile changes.

### 2. Open the DevContainer Workspace

1. Open VS Code in the repository root
2. Press `F1` → **Dev Containers: Reopen in Container**
3. VS Code connects to the running container

### 3. Verify Toolchains

Inside the container terminal:

```bash
# ESP-IDF (requires sourcing first)
get_idf
idf.py --version

# Pico SDK path
echo $PICO_SDK_PATH     # /opt/pico-sdk

# ARM GCC
arm-none-eabi-gcc --version

# Arduino CLI
arduino-cli version
```

---

## ESP32 Family (ESP-IDF)

Supported targets: `esp32`, `esp32s2`, `esp32s3`, `esp32c3`, `esp32c6`
ESP8266 is handled via Arduino CLI (see [Arduino](#arduino-esp8266--uno) section).

### Activate ESP-IDF

Required once per terminal session:

```bash
get_idf
# or: source /opt/esp/idf/export.sh
```

### Build

```bash
cd templates/esp32-c3
idf.py set-target esp32c3   # first time only; change to match your chip
idf.py build
```

**Build outputs** (`build/`):
- `bootloader/bootloader.bin`
- `partition_table/partition-table.bin`
- `<project>.bin` — application binary
- `<project>.elf` — with debug symbols

### Useful Commands

```bash
idf.py menuconfig       # interactive config
idf.py size             # binary size breakdown
idf.py fullclean        # wipe build + config
idf.py clean            # clean build artifacts only
```

### Build Task

In `DevContainer.code-workspace`: **Terminal → Run Task → Build All ESP32 Templates**

---

## Raspberry Pi Pico (RP2040/RP2350)

### Build

```bash
cd templates/rp2040       # or rp2350
mkdir build && cd build
cmake ..
make -j$(nproc)
```

**Build outputs** (`build/`):
- `<project>.elf` — with debug symbols
- `<project>.uf2` — drag-and-drop flash image
- `<project>.bin` — raw binary

### Build Task

In `DevContainer.code-workspace`: **Terminal → Run Task → Build All Pico Templates**

### Customise CMakeLists.txt

Add SDK libraries as needed:

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

Supported: `stm32f103`, `stm32f411`, `stm32f412`, `stm32g431`, `stm32h503` — all use Zephyr RTOS.

### Build

```bash
cd templates/stm32f103
cmake -B build -DBOARD=stm32_min_dev .
cmake --build build -j4
```

Board names per template:

| Template  | `-DBOARD=`             |
| --------- | ---------------------- |
| stm32f103 | `stm32_min_dev`        |
| stm32f411 | `blackpill_f411ce`     |
| stm32f412 | `nucleo_f412zg`        |
| stm32g431 | `weact_stm32g431_core` |
| stm32h503 | `nucleo_h503rb`        |

**Build outputs** (`build/zephyr/`):
- `zephyr.elf` — with debug symbols
- `zephyr.bin` — raw binary

### Build Task

In `DevContainer.code-workspace`: **Terminal → Run Task → Build All STM32 Templates**

---

## nRF52840 (Zephyr)

Template: `nrf52840` — targets the Pro Micro nRF52840 board.

### Build

```bash
cd templates/nrf52840
west build -b promicro_nrf52840
```

**Build outputs** (`build/zephyr/`):
- `zephyr.elf` — with debug symbols
- `zephyr.hex` — Intel hex for flashing

---

## Arduino (ESP8266 / Uno)

Arduino builds use the repo-local Arduino CLI. Cores are pre-installed in the container (`esp8266:esp8266`, `arduino:avr`).

### Build

```bash
cd templates/esp8266-d1mini   # or esp8266, arduino-uno
./build.sh
```

**Build outputs** (`build/`): `.elf`, `.bin` (or `.hex` for AVR)

### Build Task

In `DevContainer.code-workspace`: **Terminal → Run Task → Build All Arduino Templates**

---

## Troubleshooting

### `idf.py: command not found`

ESP-IDF tools are not on PATH until activated:

```bash
get_idf
```

### CMake can't find Pico SDK

```bash
echo $PICO_SDK_PATH   # must be /opt/pico-sdk
```

If empty, you are likely not inside the DevContainer. Reconnect via **Dev Containers: Reopen in Container**.

### Stale build after toolchain change

```bash
# ESP32
idf.py fullclean && idf.py build

# Pico / STM32
rm -rf build && mkdir build && cd build && cmake .. && make
```

### Container image out of date

Rebuild the image after Dockerfile changes:

```powershell
.\scripts\build-base-image.ps1
```

Then **Dev Containers: Rebuild Container** in VS Code.

