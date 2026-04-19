#include <stdio.h>
#include "pico/stdlib.h"
#include "hardware/gpio.h"

// Built-in LED on Raspberry Pi Pico 2
#define LED_PIN 25

int main() {
    // Initialize stdio
    stdio_init_all();
    
    // Initialize LED pin
    gpio_init(LED_PIN);
    gpio_set_dir(LED_PIN, GPIO_OUT);
    
    printf("RP2350 (Raspberry Pi Pico 2) Template Started!\n");
    printf("SDK Version: %s\n", PICO_SDK_VERSION_STRING);
    printf("Running on ARM Cortex-M33 or RISC-V Hazard3!\n");
    
    int counter = 0;
    while (true) {
        gpio_put(LED_PIN, 1);
        printf("RP2350 Blink ON - Count: %d\n", counter++);
        sleep_ms(500);
        
        gpio_put(LED_PIN, 0);
        printf("RP2350 Blink OFF\n");
        sleep_ms(500);
    }
    
    return 0;
}
