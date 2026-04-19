/**
 * STM32H503 Template - Zephyr RTOS v4.2.2
 * Board  : nucleo_h503rb (NUCLEO-H503RB, STM32H503RBT6)
 * LED    : PB0 (NUCLEO-H503RB LD1 green LED, aliased as led0 in board DTS)
 *
 * Build (container):
 *   cmake -B build -DBOARD=nucleo_h503rb . && cmake --build build -j4
 *
 * Flash (Windows host - host-only):
 *   openocd -f interface/stlink-v2-1.cfg -f target/stm32h5x.cfg
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
