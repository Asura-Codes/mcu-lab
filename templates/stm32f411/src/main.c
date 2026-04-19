/**
 * STM32F411 Template - Zephyr RTOS v4.2.2
 * Board  : blackpill_f411ce (WeAct BlackPill STM32F411CEU6)
 * LED    : PC13 (aliased as led0 in board DTS)
 *
 * Build (container):
 *   cmake -B build -DBOARD=blackpill_f411ce . && cmake --build build -j4
 *
 * Flash (Windows host - host-only):
 *   openocd -f interface/stlink.cfg -f target/stm32f4x.cfg
 *           -c "program build/zephyr/zephyr.elf verify reset exit"
 */

#include <zephyr/kernel.h>
#include <zephyr/drivers/gpio.h>
#include <zephyr/usb/usb_device.h>
#include <zephyr/sys/printk.h>
#include <zephyr/logging/log.h>
#include <zephyr/device.h>
#include <zephyr/devicetree.h>
#include <zephyr/drivers/uart.h>

#define LED0_NODE DT_ALIAS(led0)

LOG_MODULE_REGISTER(app, LOG_LEVEL_INF);

static const struct gpio_dt_spec led = GPIO_DT_SPEC_GET(LED0_NODE, gpios);

static void usb_status_cb(enum usb_dc_status_code status, const uint8_t *param)
{
    switch (status) {
    case USB_DC_CONNECTED:
        LOG_INF("USB status: CONNECTED");
        break;
    case USB_DC_DISCONNECTED:
        LOG_INF("USB status: DISCONNECTED");
        break;
    case USB_DC_CONFIGURED:
        LOG_INF("USB status: CONFIGURED");

        /* Try a direct UART write to the chosen console (CDC ACM) to verify output */
        {
            const struct device *cdc = DEVICE_DT_GET(DT_CHOSEN(zephyr_console));
            const char msg[] = "Hello CDC: USB configured\r\n";

            if (device_is_ready(cdc)) {
                for (size_t i = 0; i < sizeof(msg) - 1; i++) {
                    uart_poll_out(cdc, msg[i]);
                }
            } else {
                LOG_WRN("CDC console device not ready yet");
            }
        }
        break;
    case USB_DC_ERROR:
        LOG_ERR("USB status: ERROR");
        break;
    default:
        LOG_INF("USB status: %d", status);
        break;
    }
}

int main(void)
{
    int ret;
    const struct device *cdc = DEVICE_DT_GET(DT_CHOSEN(zephyr_console));

    gpio_pin_configure_dt(&led, GPIO_OUTPUT_ACTIVE);

    /* Enable USB device stack so console/logging goes over CDC ACM */
    LOG_INF("Enabling USB device stack");
    ret = usb_enable(usb_status_cb);
    if (ret) {
        LOG_ERR("usb_enable failed: %d", ret);
    } else {
        LOG_INF("usb_enable returned 0 (OK)");
    }

    while (1)
    {
        gpio_pin_toggle_dt(&led);
        k_msleep(500);
        LOG_INF("LED toggled");

        /* Send a short message over CDC (chosen console) if ready */
        if (device_is_ready(cdc)) {
            const char msg[] = "CDC loop: alive\r\n";
            for (size_t i = 0; i < sizeof(msg) - 1; i++) {
                uart_poll_out(cdc, msg[i]);
            }
        } else {
            LOG_DBG("CDC console not ready in loop");
        }
    }

    return 0;
}
