file /workspace/templates/esp32-wroom32/build/wroom32_blink.elf
set remotetimeout 30000
target extended-remote host.docker.internal:3333
monitor reset halt
flushregs
thb app_main
detach
