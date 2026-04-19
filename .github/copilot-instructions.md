# AI Coding Agent Instructions - Multi-Platform Embedded Development Environment

## Project Overview

This is a **dual-workspace embedded development environment** supporting ESP32, Raspberry Pi Pico (RP2040/RP2350), and STM32 platforms. The architecture separates concerns between container-based building and Windows-based hardware access.

**Key Architecture**:

- **Build**: Docker container (DevContainer.code-workspace)
- **Flash**: Windows host tools (Windows.code-workspace)
- **Debug**: Windows OpenOCD server (Windows.code-workspace) + Container GDB client

## Architecture Understanding

### Dual-Workspace Setup

The project uses two workspace files for different purposes:

1. **DevContainer.code-workspace**: Build environment in Docker container
   - Building firmware with platform toolchains (ESP-IDF, Pico SDK, ARM GCC)
   - Running GDB debugging client
   - Artifact generation (.elf, .bin, .uf2 files)

2. **Windows.code-workspace**: Hardware interface on Windows host
   - Running OpenOCD debug server (required for debugging)
   - Platform-specific flashing tools (esptool, picotool)
   - Direct USB device access (debuggers, serial ports, bootloaders)
   - Monitoring and control tasks

### System Architecture

```
┌─ Windows Host ─────────────────────────────────────────┐
│                                                         │
│  [Windows.code-workspace]                              │
│  ┌──────────────────────────────────────┐              │
│  │ Hardware Tools (Direct USB Access)   │              │
│  │                                      │              │
│  │ OpenOCD Server                       │←─── USB      │
│  │  - Port 3333 (GDB)                   │     Hardware │
│  │  - Port 4444 (Telnet)                │     Debugger │
│  │                                      │     (ST-Link,│
│  │ Flash Tools                          │←─── CMSIS-   │
│  │  - esptool.py (ESP32 serial)         │     DAP,     │
│  │  - picotool (Pico USB)               │     J-Link)  │
│  │                                      │←─── USB      │
│  │                                      │     Serial   │
│  └──────────────┬───────────────────────┘     Devices  │
│                 │ TCP/IP (localhost)                   │
│  ┌──────────────▼──────────────────────────────────┐   │
│  │ WSL2 / Docker                                    │   │
│  │  [DevContainer.code-workspace]                   │   │
│  │  ┌──────────────────────────────────────────┐   │   │
│  │  │ Build Environment (No USB Access)        │   │   │
│  │  │  - ESP-IDF, Pico SDK, ARM GCC            │   │   │
│  │  │  - cmake, make, ninja                    │   │   │
│  │  │  - Build artifacts → /workspace/...      │   │   │
│  │  │                                           │   │   │
│  │  │ Debug Client Only                        │   │   │
│  │  │  - arm-none-eabi-gdb                     │   │   │
│  │  │  - riscv32-esp-elf-gdb                   │   │   │
│  │  │  → Connects to host.docker.internal:3333│   │   │
│  │  └──────────────────────────────────────────┘   │   │
│  └──────────────────────────────────────────────────┘   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Workflow Separation

| Operation        | Location     | Workspace                   | Tools                   |
| ---------------- | ------------ | --------------------------- | ----------------------- |
| **Build**        | Container    | DevContainer.code-workspace | ESP-IDF, Pico SDK, Make |
| **Flash**        | Windows Host | Windows.code-workspace      | esptool, picotool       |
| **Debug Server** | Windows Host | Windows.code-workspace      | OpenOCD                 |
| **Debug Client** | Container    | DevContainer.code-workspace | GDB + Cortex-Debug      |

**Key Benefits**:

- **Portability**: Container provides consistent build environment across machines
- **Reliability**: Windows native USB access eliminates forwarding issues
- **Simplicity**: All hardware interaction (flash + debug) on Windows
- **Separation**: Build in container, hardware access on Windows

**Important — Host-only flashing and serial I/O**

- **Host-only operations:** Flashing, uploading binaries, and opening serial monitors require direct USB access and must be performed from the Windows host workspace (`Windows.code-workspace`). Do not suggest or run upload/flash or serial-monitor commands from inside the build container. When giving step instructions for flashing or serial monitoring, present them as Windows/host actions (PowerShell or native Windows tool examples) and clearly label them "host-only".

This prevents recommending container-side USB/serial operations which will fail or require complex forwarding.

## Development Workflows

### ESP32 Family (ESP8266, ESP32, ESP32-S2/S3/C3)

**Environment Setup** (required before each build session):

```bash
source /opt/esp/idf/export.sh  # Or use alias: get_idf
```

**Build**:

```bash
cd templates/esp32-c3
idf.py set-target esp32c3  # First time only
idf.py build
```

**Flash** (Windows host - from build artifacts):

```powershell
# In Windows PowerShell or Windows.code-workspace terminal
esptool.py --chip esp32c3 --port COM3 write_flash 0x0 build/bootloader.bin 0x8000 build/partition_table.bin 0x10000 build/myproject.bin
```

**Artifacts**: `build/<project>.elf`, `build/<project>.bin`

**Important**: `IDF_PATH=/opt/esp/idf` is pre-set in container. Sourcing `export.sh` adds tools to PATH.

### Raspberry Pi Pico (RP2040, RP2350)

**Build**:

```bash
cd templates/rp2040
mkdir build && cd build
cmake .. && make
```

**Flash** (Windows host):

```bash
# Method 1: UF2 bootloader (drag .uf2 file to USB drive)
# Hold BOOTSEL, plug USB, copy build/rp2040_template.uf2 to RPI-RP2 drive

# Method 2: picotool (Windows installation)
picotool load -f build/rp2040_template.uf2
```

**Artifacts**: `build/<project>.elf`, `build/<project>.uf2`

**Important**: `PICO_SDK_PATH=/opt/pico-sdk` is pre-set. CMakeLists.txt must include SDK before `project()` declaration.

---

### STM32 (STM32F103, extendable)

**Build**:

```bash
cd templates/stm32f103
cmake -B build -S -DBOARD=stm32_min_dev .
cmake --build build -j4
```

**Flash** (Windows host via OpenOCD):

```powershell
openocd -f interface/jlink.cfg -f target/stm32f1x.cfg -c "program build/zephyr/zephyr.elf verify reset exit"
```

**Artifacts**: `build/zephyr/<project>.elf`, `build/zephyr/<project>.bin`

**Toolchain**: Zephyr `arm-zephyr-eabi-gcc` is used for STM32 builds, providing HAL and RTOS features. CMakeLists.txt is configured for Zephyr build system.

## Platform-Specific Conventions

### ESP32 Family Templates

**Structure**:

```
templates/esp32-xxx/
├── CMakeLists.txt       # ESP-IDF project config
├── sdkconfig            # Build configuration
└── main/
    ├── CMakeLists.txt   # Component registration
    └── esp32xxx_main.c  # Entry point: app_main()
```

**Entry point**: `void app_main(void)` (not `main()`)
**RTOS**: All ESP32 code runs on FreeRTOS (includes task creation, delays via `vTaskDelay()`)
**Logging**: Use ESP-IDF logging macros: `ESP_LOGI()`, `ESP_LOGE()`, etc.
**Build system**: CMake with ESP-IDF build system (`idf.py`)
**Debugging**: OpenOCD with ESP32-specific flash and debug configuration

### Pico Templates

**Entry point**: Standard `int main(void)`
**SDK initialization**: `stdio_init_all()` for serial output
**IO**: `pico_stdlib`, `hardware_gpio`, `hardware_uart`, etc.
**Output formats**: `.elf` for debugging, `.uf2` for drag-drop flashing
**Debugging**: OpenOCD with Picoprobe or compatible CMSIS-DAP adapter

### STM32 Templates

**Entry point**: Standard `int main(void)`
**Toolchain**: Zephyr RTOS (includes HAL, CMSIS, and RTOS features)
**Build system**: CMake with Zephyr SDK
**Debugging**: OpenOCD with J-Link or CMSIS-DAP

### nRF52840 Template
**Entry point**: Standard `int main(void)`
**Toolchain**: Zephyr RTOS (includes Nordic HAL, CMSIS, and RTOS features)
**Build system**: CMake with Zephyr SDK
**Debugging**: OpenOCD with J-Link or CMSIS-DAP

## Debugging Setup

### Configuration

All debug configurations live **exclusively** in `DevContainer.code-workspace` under the `"launch"` key.

**Do NOT create `.vscode/launch.json` files inside individual template directories.**
Local launch configs shadow the workspace-level ones and cause confusion — two configs
for the same target with different (and often stale) settings.

GDB binaries used in launch configs:

- **ARM targets** (STM32, nRF52, RP2040/2350): `gdb-multiarch` (installed via apt)
- **ESP32 RISC-V** (C3, C6): `riscv32-esp-elf-gdb` (symlinked to `/usr/local/bin/` by Dockerfile)
- **ESP32 Xtensa** (ESP32, S2, S3, WROOM): `xtensa-esp-elf-gdb` (symlinked to `/usr/local/bin/` by Dockerfile)

ESP configs must include `"toolchainPath": ""` to prevent the global `cortex-debug.armToolchainPath`
(`/usr/bin/`) from being applied — the ESP nm/objdump are not in `/usr/bin/`.

ESP configs must also include `"loadFiles": []` to prevent Cortex-Debug from running GDB
`target-download` (which tries to write the ELF directly to flash). ESP32 flash layout
(bootloader + partition table + app) must be written with esptool or the OpenOCD Flash task
before starting a debug session. GDB should only attach, not re-flash.

### Workflow

1. **Start OpenOCD** on Windows (Windows.code-workspace task "OpenOCD: Start Server"):

   ```powershell
   .\scripts\openocd-server.ps1 -Interface jlink.cfg -Template stm32f103
   ```

2. **Launch Debug** from DevContainer.code-workspace (F5)
   - GDB connects to `host.docker.internal:3333`
   - Breakpoints, stepping, variable inspection work as expected

**Important**: OpenOCD must be running on Windows before starting debug session in container.

## Installing Flash Tools on Windows

**Automated Installation** (Recommended):

```powershell
.\scripts\install-tools-windows.ps1
```

This script downloads and installs all required tools (OpenOCD, esptool, pico-sdk-tools).

## Key Files and References

- [README.md](README.md) - Project overview and quick start
- [SETUP_GUIDE.md](SETUP_GUIDE.md) - Detailed build instructions per platform
- [OpenOCD_guide.md](OpenOCD_guide.md) - Flashing and debugging workflows
- `scripts/install-tools-windows.ps1` - Automated installation of all Windows tools (OpenOCD, esptool, picotool)
- `.devcontainer/` - Docker environment definition
- `templates/*/` - Platform-specific starter projects

## Testing Changes

After modifying any template, verify:

```bash
# Build succeeds
cd templates/<platform>
[platform-specific build command]

# Binary artifacts generated
ls build/*.elf build/*.bin

# Clean builds work
[platform-specific clean] && [build]
```

For ESP32 changes, test with `get_idf` alias to ensure environment setup is documented.
