/**
 * STM32G431 Template — Zephyr RTOS v4.2.2
 * Board  : weact_stm32g431_core (NUCLEO-G431RB, STM32G431RBT6)
 * LED    : PB8 (Nucleo-G431RB LD2 green LED, aliased as led0 in board DTS)
 *
 * Build (container):
 *   cmake -B build -DBOARD=weact_stm32g431_core . && cmake --build build -j4
 *
 * Flash (Windows host — host-only):
 *   openocd -f interface/stlink.cfg -f target/stm32g4x.cfg \
 *           -c "program build/zephyr/zephyr.elf verify reset exit"
 */

#include <zephyr/kernel.h>
#include <zephyr/drivers/gpio.h>

#define LED0_NODE DT_ALIAS(led0)

static const struct gpio_dt_spec led = GPIO_DT_SPEC_GET(LED0_NODE, gpios);

int main(void)
{
    gpio_pin_configure_dt(&led, GPIO_OUTPUT_ACTIVE);

    while (1)
    {
        gpio_pin_toggle_dt(&led);
        k_msleep(500);
    }

    return 0;
}

