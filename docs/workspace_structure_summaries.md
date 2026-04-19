# Workspace Structure Summaries

This document summarizes the key files and their purposes in the mcu-lab repository.

## Repository Organization

The repository is organized into distinct functional areas:

### Core Workspaces

- **DevContainer.code-workspace** — Multi-folder workspace for building firmware inside Docker container
- **Windows.code-workspace** — Single-folder workspace for Windows host operations (flashing, debugging, serial I/O)

### Container Environment (`.devcontainer/`)

| File                         | Purpose                                                              |
| ---------------------------- | -------------------------------------------------------------------- |
| `Dockerfile`                 | Builds Ubuntu 24.04 image with ESP-IDF, Pico SDK, Zephyr, ARM GCC    |
| `docker-compose.yml`         | Development composition (builds image locally)                       |
| `docker-compose.runtime.yml` | Runtime composition (pulls `asuracodes/mcu-lab:base` from DockerHub) |
| `devcontainer.json`          | VS Code Dev Containers configuration                                 |

**Key Details:**
- Base image: `asuracodes/mcu-lab:base` (~26 GB)
- Contains: ESP-IDF 6.0, Pico SDK 2.2.0, Zephyr RTOS 4.2.2, Zephyr SDK 0.17.4, ARM GCC, Arduino CLI 1.4.1, west
- Environment variables preset: `IDF_PATH`, `PICO_SDK_PATH`, `IDF_TOOLS_PATH`, `ZEPHYR_BASE`, `ZEPHYR_SDK_INSTALL_DIR`
- Docker volume mounts workspace to `/workspace`

### Templates (`templates/`)

firmware templates, each with:
- `.vscode/tasks.json` — Build, clean, and menuconfig tasks
- `.vscode/c_cpp_properties.json` — IntelliSense configuration
- Source files and build configuration

**Template Categories:**
1. **ESP32 (ESP-IDF):** `esp32`, `esp32-wroom32`, `esp32-c3`, `esp32-c6`, `esp32-s2`, `esp32-s3`
2. **Raspberry Pi Pico (Pico SDK):** `rp2040`, `rp2350`
3. **STM32 (Zephyr):** `stm32f103`, `stm32f411`, `stm32f412`, `stm32g431`, `stm32h503`
4. **Nordic (Zephyr):** `nrf52840`
5. **Arduino:** `esp8266`, `esp8266-d1mini`, `arduino-uno`

Each ESP-IDF template has tasks that source `/opt/esp/idf/export.sh` before running `idf.py`.

### Windows Flash Tools (`flash/`)

Tools bundled for Windows host flashing and programming:

| Tool                | Location                       | Purpose                                   |
| ------------------- | ------------------------------ | ----------------------------------------- |
| `arduino-cli.exe`   | `flash/arduino-cli/`           | Arduino compilation and upload            |
| `arduino-cli-data/` | `flash/arduino-cli-data/`      | Core packages (ESP8266, AVR)              |
| `picotool.exe`      | `flash/picotool/picotool/`     | Raspberry Pi Pico flashing (BOOTSEL mode) |
| `pioasm.exe`        | `flash/pico-sdk-tools/pioasm/` | PIO assembler for Pico development        |
| `ZADIG-2.9.exe`     | `flash/zadig/`                 | WinUSB driver installer for USB devices   |

**Note:** `esptool.py` is installed via Python pip, not bundled in `flash/`.

### OpenOCD Executables (`openocd/`)

Three OpenOCD variants for different platforms:

| Variant                   | Use Case                                      |
| ------------------------- | --------------------------------------------- |
| `xpack-openocd-0.12.0-7/` | Universal (STM32, RP2040 with J-Link)         |
| `openocd-esp32/`          | ESP32 family (required for ESP flash drivers) |
| `pico/`                   | RP2040/RP2350 with CMSIS-DAP/Picoprobe        |

Scripts automatically select the appropriate variant based on template and interface.

### PowerShell Scripts (`scripts/`)

Modular script architecture for OpenOCD operations:

**Core Utility Scripts:**

| Script              | Purpose                                                                 |
| ------------------- | ----------------------------------------------------------------------- |
| `path.ps1`          | Discovers OpenOCD executables, sets `OPENOCD_EXE` and `OPENOCD_SCRIPTS` |
| `template.ps1`      | Template selection, sets `OPENOCD_TEMPLATE_NAME` and path               |
| `interface.ps1`     | Interface selection, sets `OPENOCD_INTERFACE`                           |
| `target.ps1`        | Target selection, sets `OPENOCD_TARGET`                                 |
| `config.ps1`        | Maps templates to default interface/target configs                      |
| `openocd-utils.ps1` | Shared helper functions for OpenOCD operations                          |

**User-Facing Scripts:**

| Script                      | Purpose                                               |
| --------------------------- | ----------------------------------------------------- |
| `openocd-server.ps1`        | Start OpenOCD GDB server (port 3333)                  |
| `openocd-flash.ps1`         | Flash firmware via OpenOCD                            |
| `openocd-detect.ps1`        | Auto-detect connected debug adapters                  |
| `openocd-info.ps1`          | Query chip info via JTAG                              |
| `install-tools-windows.ps1` | Download and install all Windows tools                |
| `build-base-image.ps1`      | Build Docker image locally                            |
| `arduino-cli.cmd`           | Wrapper for repo-local Arduino CLI with custom config |

**Script Chain:** Most scripts follow this initialization pattern:
```powershell
. path.ps1          # Find OpenOCD
. template.ps1      # Select template
. interface.ps1     # Select interface
. target.ps1        # Select target
```

Environment variables communicate between scripts (`OPENOCD_*` prefix).

### Documentation (`docs/`)

| File               | Content                                                      |
| ------------------ | ------------------------------------------------------------ |
| `SETUP_GUIDE.md`   | Detailed build instructions for each platform                |
| `OpenOCD_guide.md` | OpenOCD workflow explanation, script architecture, debugging |

## Workflow Summary

### Building (Container)

1. Open `DevContainer.code-workspace` in VS Code
2. Reopen in container (pulls `asuracodes/mcu-lab:base` from DockerHub)
3. Navigate to template folder
4. Run build task from `.vscode/tasks.json` or manually:
   - **ESP32:** `source /opt/esp/idf/export.sh && idf.py build`
   - **Pico:** `cmake -B build && cmake --build build`
   - **STM32/nRF52:** `cmake -B build -DBOARD=<board> . && cmake --build build`

### Flashing (Windows Host)

1. Open `Windows.code-workspace`
2. Run appropriate task:
   - **OpenOCD:** `OpenOCD: Flash` (interactive)
   - **ESP32:** `Flash: ESP32 via esptool.py`
   - **Pico:** `Flash: Pi Pico via picotool` (BOOTSEL mode)
   - **Arduino:** `Flash: arduino-cli upload`

### Debugging (Dual-Workspace)

1. **Windows workspace:** Run `OpenOCD: Start Server` task
   - Starts OpenOCD on Windows with direct USB access
   - Listens on `localhost:3333` (GDB) and `localhost:4444` (Telnet)
2. **DevContainer workspace:** Press F5
   - GDB in container connects to `host.docker.internal:3333`
   - Debug configurations in workspace `launch` settings

## Key Design Decisions

### Why Dual Workspaces?

Docker USB passthrough on Windows (WSL2) is unreliable. Separating concerns:
- **Container:** Reproducible builds with all toolchains
- **Windows:** Native USB access for hardware operations

### Why DockerHub Image?

The 26 GB image includes ESP-IDF, Pico SDK, Zephyr, and all toolchains. Hosting on DockerHub (`asuracodes/mcu-lab:base`) makes it portable and avoids rebuilding on every machine.

### Why Multiple OpenOCD Variants?

- **ESP32 OpenOCD** has flash drivers for ESP32 family
- **Pico OpenOCD** optimized for RP2040/RP2350 with CMSIS-DAP
- **xPack OpenOCD** universal for STM32 and J-Link

Scripts auto-select the appropriate variant based on template name and interface config.

### Why Bundled Windows Tools?

Bundling tools in the repository under `flash/` and `openocd/` ensures:
- No global PATH pollution
- Version consistency
- Portability (clone repo and go)
- Python pip packages (esptool) remain separate for flexibility

## Template Task Structure

Each template's `.vscode/tasks.json` provides platform-specific build tasks:

**ESP32 Templates:**
- Build: `source /opt/esp/idf/export.sh && idf.py build`
- Clean: `idf.py fullclean`
- Menuconfig: `idf.py menuconfig`

**Pico Templates:**
- Configure: `cmake -B build -S .`
- Build: `cmake --build build -j4`
- Clean: `rm -rf build`

**STM32/nRF52 Templates:**
- Configure: `cmake -B build -DBOARD=<board> .`
- Build: `cmake --build build -j4`
- Menuconfig: `west build -t menuconfig`
- Clean: `rm -rf build`

**Arduino Templates:**
- Build: `arduino-cli compile`
- Upload: `arduino-cli upload`

## Environment Variables Reference

### Container Environment

| Variable                 | Value                       | Set By     |
| ------------------------ | --------------------------- | ---------- |
| `IDF_PATH`               | `/opt/esp/idf`              | Dockerfile |
| `IDF_TOOLS_PATH`         | `/opt/esp`                  | Dockerfile |
| `PICO_SDK_PATH`          | `/opt/pico-sdk`             | Dockerfile |
| `ZEPHYR_BASE`            | `/opt/zephyrproject/zephyr` | Dockerfile |
| `ZEPHYR_SDK_INSTALL_DIR` | `/opt/zephyr-sdk-0.17.4`    | Dockerfile |

### Windows Scripts (PowerShell)

| Variable                | Purpose                                  | Set By          |
| ----------------------- | ---------------------------------------- | --------------- |
| `OPENOCD_EXE`           | Path to selected `openocd.exe`           | `path.ps1`      |
| `OPENOCD_SCRIPTS`       | Path to OpenOCD scripts directory        | `path.ps1`      |
| `OPENOCD_TEMPLATE_NAME` | Template folder name (e.g., `stm32f103`) | `template.ps1`  |
| `OPENOCD_TEMPLATE_PATH` | Full path to template directory          | `template.ps1`  |
| `OPENOCD_INTERFACE`     | Interface config (e.g., `jlink.cfg`)     | `interface.ps1` |
| `OPENOCD_TARGET`        | Target config (e.g., `stm32f1x.cfg`)     | `target.ps1`    |
| `OPENOCD_ADAPTER_SPEED` | Adapter speed in kHz (default: 4000)     | User input      |

These variables persist across script chain execution and are used by `openocd-server.ps1` and `openocd-flash.ps1`.
