/**
 * STM32F103 Template — Zephyr RTOS
 * Simple blink using PC13. Keeps code minimal and avoids devicetree.
 *
 * Build:
 *   cmake -B build -DBOARD=<board_name> . && cmake --build build -j4
 *
 * Flash (host):
 *   openocd -f interface/stlink.cfg -f target/stm32f1x.cfg \
 *     -c "program build/zephyr/zephyr.elf verify reset exit"
 */

#include <zephyr/kernel.h>
#include <zephyr/device.h>
#include <zephyr/drivers/gpio.h>
#include <zephyr/sys/printk.h>
#include <zephyr/devicetree.h>

/* Use the devicetree node label for the GPIO controller so lookup is
 * robust even if the node has no explicit "label" property.
 */
#define GPIOC_NODE DT_NODELABEL(gpioc)
#define LED_PIN  13U

int main(void)
{
    printk("stm32f103 blink diagnostic start\n");

    printk("Looking up GPIO device by DT nodelabel 'gpioc'\n");
    const struct device *gpio = DEVICE_DT_GET(GPIOC_NODE);
    if (!device_is_ready(gpio)) {
        printk("Error: GPIO device not ready or not found (DT nodelabel 'gpioc')\n");
        return 0;
    }
    printk("Got device pointer %p\n", (void *)gpio);

    /* Configure as a plain output and explicitly set an initial level. */
    int ret = gpio_pin_configure(gpio, LED_PIN, GPIO_OUTPUT);
    if (ret) {
        printk("Failed to configure gpioc:%u: %d\n", LED_PIN, ret);
        return 0;
    }
    printk("Configured gpioc:%u as output\n", LED_PIN);

    ret = gpio_pin_set(gpio, LED_PIN, 1);
    if (ret) {
        printk("Failed to set gpioc:%u: %d\n", LED_PIN, ret);
        return 0;
    }
    printk("Initial pin set OK\n");

    while (1) {
        ret = gpio_pin_toggle(gpio, LED_PIN);
        if (ret) {
            printk("gpio_pin_toggle failed: %d\n", ret);
            k_msleep(500);
            continue;
        }
        k_msleep(500);
    }

    return 0;
}


// #define LED0_NODE DT_ALIAS(led0)

// static const struct gpio_dt_spec led = GPIO_DT_SPEC_GET(LED0_NODE, gpios);

// int main(void)
// {
//     gpio_pin_configure_dt(&led, GPIO_OUTPUT_ACTIVE);

//     while (1)
//     {
//         gpio_pin_toggle_dt(&led);
//         k_msleep(100);
//     }

//     return 0;
// }
