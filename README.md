# mcu-lab

Embedded development across multiple platforms means installing different SDKs, toolchains, and debugging tools. Installing ESP-IDF, Pico SDK, Zephyr, ARM GCC, and OpenOCD directly on Windows can get messy.

This repository provides a Docker container with all the build toolchains already installed. The container image (~26 GB) is hosted on DockerHub as `asuracodes/mcu-lab:base`, so you can pull it when needed. Building happens inside the container for reproducibility. Flashing and debugging happen on Windows because USB passthrough to Docker on Windows isn't reliable enough.

The setup isn't perfect, but it works. I chose to keep hardware operations native on Windows rather than fight with USB forwarding issues.

## Supported Platforms

The repository includes templates for:

| Platform          | Template         | Architecture   | SDK/Framework |
| ----------------- | ---------------- | -------------- | ------------- |
| ESP32 family      | `esp32`          | Xtensa LX6     | ESP-IDF       |
|                   | `esp32-wroom32`  | Xtensa LX6     | ESP-IDF       |
|                   | `esp32-c3`       | RISC-V         | ESP-IDF       |
|                   | `esp32-c6`       | RISC-V         | ESP-IDF       |
|                   | `esp32-s2`       | Xtensa LX7     | ESP-IDF       |
|                   | `esp32-s3`       | Xtensa LX7     | ESP-IDF       |
| Raspberry Pi Pico | `rp2040`         | ARM Cortex-M0+ | Pico SDK      |
|                   | `rp2350`         | ARM Cortex-M33 | Pico SDK      |
| STM32             | `stm32f103`      | ARM Cortex-M3  | Zephyr RTOS   |
|                   | `stm32f411`      | ARM Cortex-M4F | Zephyr RTOS   |
|                   | `stm32f412`      | ARM Cortex-M4F | Zephyr RTOS   |
|                   | `stm32g431`      | ARM Cortex-M4F | Zephyr RTOS   |
|                   | `stm32h503`      | ARM Cortex-M33 | Zephyr RTOS   |
| Nordic            | `nrf52840`       | ARM Cortex-M4F | Zephyr RTOS   |
| Arduino           | `esp8266`        | Xtensa L106    | Arduino Core  |
|                   | `esp8266-d1mini` | Xtensa L106    | Arduino Core  |
|                   | `arduino-uno`    | ATmega328P     | Arduino Core  |

Each template has `.vscode/tasks.json` for build/clean/menuconfig, debug configurations, and SVD files for peripheral inspection.

## Repository Structure

```
templates/          # firmware templates, each with .vscode/tasks.json
flash/              # Windows tools: picotool, arduino-cli, zadig
openocd/            # OpenOCD variants: xPack, ESP32, Pico
scripts/            # PowerShell scripts for flashing/debugging

DevContainer.code-workspace   # Open in Docker container for building
Windows.code-workspace        # Open on Windows for flashing/debugging
```

## Two Workspaces

I use two VS Code workspaces because Docker USB passthrough on Windows doesn't work reliably:

| Workspace                     | Environment      | What It Does                         |
| ----------------------------- | ---------------- | ------------------------------------ |
| `DevContainer.code-workspace` | Docker container | Builds firmware, runs GDB client     |
| `Windows.code-workspace`      | Windows host     | Flashes devices, runs OpenOCD server |

The container pulls from `asuracodes/mcu-lab:base` and includes:
- ESP-IDF 6.0 at `/opt/esp/idf`
- Pico SDK 2.2.0 at `/opt/pico-sdk`
- Zephyr RTOS
- ARM GCC, CMake, Ninja, Arduino CLI

## Building (in the Container)

Open `DevContainer.code-workspace` and select **Dev Containers: Reopen in Container**.

**Workspace tasks** (Terminal → Run Task):
- Build All Templates
- Build All ESP32 Templates
- Build All Pico Templates
- Build All STM32 Templates
- Build All Arduino Templates
- Clean All Templates

**Template tasks** — Each template folder has `.vscode/tasks.json` with:
- Build
- Clean
- Menuconfig (ESP-IDF and Zephyr only)

Manual build examples:

```bash
# ESP32-C3
cd templates/esp32-c3
source /opt/esp/idf/export.sh
idf.py build

# RP2040
cd templates/rp2040
cmake -B build && cmake --build build

# STM32F103
cd templates/stm32f103
cmake -B build -DBOARD=stm32_min_dev .
cmake --build build -j4
```

## Flashing (on Windows)

Open `Windows.code-workspace` in a separate window.

**Tasks** (Terminal → Run Task):

| Task                        | What It Does                              |
| --------------------------- | ----------------------------------------- |
| Install Windows Tools       | Downloads OpenOCD, picotool, arduino-cli  |
| OpenOCD: Start Server       | Starts GDB server (port 3333)             |
| OpenOCD: Flash              | Flash via OpenOCD (interactive selection) |
| OpenOCD: Detect Hardware    | Auto-detect connected debuggers           |
| OpenOCD: Target Info        | Read chip ID via JTAG                     |
| Flash: ESP32 via esptool.py | Flash ESP32 over serial (Python pip)      |
| Flash: Pi Pico via picotool | Flash Pico in BOOTSEL mode                |
| Flash: arduino-cli upload   | Upload Arduino sketches                   |
| Serial Monitor              | Open serial monitor (Python miniterm)     |

PowerShell scripts in `scripts/` back these tasks. You can also run them directly:

```powershell
.\scripts\openocd-server.ps1
.\scripts\openocd-flash.ps1
.\scripts\openocd-detect.ps1
.\scripts\install-tools-windows.ps1
```

**Note:** The install script downloads tools into `flash/` and `openocd/` directories. `esptool.py` is installed via `pip install esptool` (requires Python).

## Debugging

Debugging requires both workspaces:

1. **Windows workspace**: Run **OpenOCD: Start Server**
   - Starts OpenOCD with direct USB access
   - Listens on localhost:3333 (GDB) and localhost:4444 (Telnet)

2. **DevContainer workspace**: Press **F5**
   - GDB connects to `host.docker.internal:3333`
   - All debug configs are in the workspace launch settings

## OpenOCD Variants

The `openocd/` directory can hold three OpenOCD versions. The scripts auto-select based on your template and debug adapter:

| Package                   | Best For                             |
| ------------------------- | ------------------------------------ |
| `xpack-openocd-0.12.0-7/` | STM32, RP2040 with J-Link            |
| `openocd-esp32/`          | ESP32 family (has ESP flash drivers) |
| `pico/`                   | RP2040/RP2350 with CMSIS-DAP         |

The **Install Windows Tools** task downloads these.

## Getting Started

1. Install Docker Desktop (WSL2 backend), VS Code with Dev Containers extension
2. Install USB drivers: ST-Link for STM32, CP210x/FTDI for ESP32
3. Pull the container: `docker pull asuracodes/mcu-lab:base`
4. Open `DevContainer.code-workspace` and reopen in container
5. Open `Windows.code-workspace` in a separate window
6. Run **Install Windows Tools** from Windows workspace
7. Build a template, flash it, debug it

## SVD Files

SVD files for peripheral debugging are in each template directory:

- **STM32**: From [cmsis-svd-stm32](https://github.com/modm-io/cmsis-svd-stm32)
- **ESP32**: From [Espressif's SVD repo](https://github.com/espressif/svd)
- **Pico**: From Pico SDK (`/opt/pico-sdk/`)
- **nRF52840**: From Zephyr (`/opt/zephyrproject/modules/hal/nordic/nrfx/mdk/nrf52840.svd`)

## Documentation

- [docs/SETUP_GUIDE.md](docs/SETUP_GUIDE.md) — Build instructions per platform
- [docs/OpenOCD_guide.md](docs/OpenOCD_guide.md) — OpenOCD workflow and script details
- [docs/workspace_structure_summaries.md](docs/workspace_structure_summaries.md) — File structure and design decisions
