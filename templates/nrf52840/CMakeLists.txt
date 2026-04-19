cmake_minimum_required(VERSION 3.20.0)

# Locate Zephyr from the upstream Zephyr workspace
find_package(Zephyr REQUIRED HINTS $ENV{ZEPHYR_BASE})

project(nrf52840_template
    VERSION 1.0.0
    DESCRIPTION "nRF52840 blink template (Zephyr RTOS v4.2.2)"
    LANGUAGES C
)

target_sources(app PRIVATE src/main.c)
