cmake_minimum_required(VERSION 3.20.0)

# If a project devicetree overlay exists, pass it to the Zephyr build
# so the overlay is applied during the initial configure step.
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/prj.overlay")
	set(DTC_OVERLAY_FILE "${CMAKE_CURRENT_SOURCE_DIR}/prj.overlay" CACHE STRING "Device tree overlay file for project")
endif()

find_package(Zephyr REQUIRED HINTS $ENV{ZEPHYR_BASE})

project(stm32f411_template)

target_sources(app PRIVATE src/main.c)

