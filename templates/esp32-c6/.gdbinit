file /workspace/templates/esp32-c6/build/esp32c6_template.elf
set remotetimeout 10000
target extended-remote host.docker.internal:3333
monitor reset halt
flushregs
thb app_main
detach
