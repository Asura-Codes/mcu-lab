cmake_minimum_required(VERSION 3.20.0)

set(BOARD_REVISION "blue" CACHE STRING "Board revision to build for")

find_package(Zephyr REQUIRED HINTS $ENV{ZEPHYR_BASE})

project(stm32f103_template)

target_sources(app PRIVATE src/main.c)
