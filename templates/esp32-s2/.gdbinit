file /workspace/templates/esp32-s2/build/esp32s2_template.elf
set remotetimeout 10000
target extended-remote host.docker.internal:3333
monitor reset halt
flushregs
thb app_main
detach
