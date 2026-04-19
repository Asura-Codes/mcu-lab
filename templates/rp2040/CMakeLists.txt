cmake_minimum_required(VERSION 3.13)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Set board type for RP2040
set(PICO_BOARD pico)
set(PICO_PLATFORM rp2040)
set(PICO_COMPILER pico_arm_cortex_m0plus_gcc)
set(PICO_GCC_TRIPLE arm-none-eabi)

# Pull in SDK (must be before project)
include($ENV{PICO_SDK_PATH}/external/pico_sdk_import.cmake)

project(rp2040_template C CXX ASM)
set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

# Initialize the SDK
pico_sdk_init()

add_executable(rp2040_template
    main.c
)

# Pull in common dependencies
target_link_libraries(rp2040_template
    pico_stdlib
    hardware_gpio
)

# Enable USB output, disable UART output
pico_enable_stdio_usb(rp2040_template 1)
pico_enable_stdio_uart(rp2040_template 0)

# Create map/bin/hex/uf2 files
pico_add_extra_outputs(rp2040_template)
