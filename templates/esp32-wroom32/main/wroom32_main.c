#include <stdio.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_log.h"
#include "driver/gpio.h"

static const char *TAG = "WROOM32_BLINK";

/*
 * ESP-WROOM-32 (ESP-WROOM-32D) - LED Blink Example
 *
 * The ESP-WROOM-32D is the RF module; most development boards break out
 * an LED on GPIO2 (active HIGH).  If your board uses a different pin,
 * change BLINK_GPIO below.
 *
 * Blink rate: 500 ms on / 500 ms off (1 Hz)
 */
#define BLINK_GPIO  GPIO_NUM_2  /* Common LED pin on WROOM-32 devkits */
#define BLINK_DELAY_MS 1000

void app_main(void)
{
    ESP_LOGI(TAG, "ESP-WROOM-32 (ESP-WROOM-32D) - LED Blink Started");
    ESP_LOGI(TAG, "SDK Version: %s", esp_get_idf_version());
    ESP_LOGI(TAG, "LED on GPIO%d (active HIGH)", BLINK_GPIO);

    gpio_reset_pin(BLINK_GPIO);
    gpio_set_direction(BLINK_GPIO, GPIO_MODE_OUTPUT);

    int level = 0;
    while (1) {
        gpio_set_level(BLINK_GPIO, level);
        ESP_LOGI(TAG, "LED %s", level ? "ON" : "OFF");
        level = !level;
        vTaskDelay(pdMS_TO_TICKS(BLINK_DELAY_MS));
    }
}
