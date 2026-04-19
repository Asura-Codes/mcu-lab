#include <zephyr/kernel.h>
#include <zephyr/drivers/gpio.h>
#include <zephyr/usb/usb_device.h>
#include <zephyr/logging/log.h>

LOG_MODULE_REGISTER(app, LOG_LEVEL_INF);

#define LED0_NODE DT_ALIAS(led0)

#if !DT_NODE_HAS_STATUS(LED0_NODE, okay)
#error "DT alias led0 is not defined in the board overlay"
#endif

static const struct gpio_dt_spec led = GPIO_DT_SPEC_GET(LED0_NODE, gpios);

int main(void)
{
    int ret;
    uint32_t blink_count = 0;

    /* Enable USB device stack so console/logging goes over CDC ACM */
    ret = usb_enable(NULL);
    if (ret) {
        LOG_ERR("usb_enable failed: %d", ret);
    } else {
        LOG_INF("usb_enable returned 0 (OK)");
    }

    if (!gpio_is_ready_dt(&led))
    {
        LOG_ERR("LED GPIO device is not ready");
        return -ENODEV;
    }

    ret = gpio_pin_configure_dt(&led, GPIO_OUTPUT_INACTIVE);
    if (ret != 0)
    {
        LOG_ERR("Failed to configure LED GPIO (err %d)", ret);
        return ret;
    }

    LOG_INF("WeAct STM32F412 app started");

    while (1)
    {
        ret = gpio_pin_toggle_dt(&led);
        if (ret != 0)
        {
            LOG_ERR("Failed to toggle LED (err %d)", ret);
        }

        LOG_INF("blink %u", blink_count++);
        k_msleep(500);
    }
}
