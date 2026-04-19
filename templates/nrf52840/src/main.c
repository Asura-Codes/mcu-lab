/**
 * nRF52840 Template — Zephyr RTOS v4.2.2
 * Board : promicro_nrf52840
 * LED   : led0 alias from board devicetree
 *
 * Build (container):
 *   cmake -B build -DBOARD=promicro_nrf52840 . && cmake --build build -j4
 *
 * Flash (Windows host — host-only):
 *   nrfjprog --program build/zephyr/zephyr.hex --chiperase --verify --reset
 *   # or: openocd -f interface/cmsis-dap.cfg -f target/nordic/nrf52.cfg \
 *   #             -c "program build/zephyr/zephyr.elf verify reset exit"
 */

#include <errno.h>
#include <zephyr/kernel.h>
#include <zephyr/device.h>
#include <zephyr/drivers/gpio.h>
#include <zephyr/sys/printk.h>
#include <zephyr/usb/usb_device.h>

/* Get LED0 from board devicetree */
static const struct gpio_dt_spec led = GPIO_DT_SPEC_GET(DT_ALIAS(led0), gpios);

int main(void)
{
    int ret = usb_enable(NULL);
    if ((ret != 0) && (ret != -EALREADY))
    {
        return ret;
    }

    printk("main reached\n");

    if (!device_is_ready(led.port))
    {
        printk("LED device not ready\n");
        return -1;
    }

    ret = gpio_pin_configure_dt(&led, GPIO_OUTPUT_ACTIVE);
    if (ret < 0)
    {
        printk("Failed to configure LED: %d\n", ret);
        return ret;
    }

    printk("LED configured, starting blink loop\n");

    uint32_t toggle_count = 0;
    while (1)
    {
        gpio_pin_toggle_dt(&led);
        toggle_count++;
        printk("Toggle count: %u\n", toggle_count);
        k_msleep(500);
    }

    return 0;
}
