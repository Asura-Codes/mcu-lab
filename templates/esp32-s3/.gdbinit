file /workspace/templates/esp32-s3/build/esp32s3_template.elf
set remotetimeout 10000
target extended-remote host.docker.internal:3333
monitor reset halt
flushregs
thb app_main
detach
