#include <stdio.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_system.h"
#include "esp_log.h"
#include "driver/gpio.h"
#include "tinyusb.h"

static const char *TAG = "ESP32S2_TEMPLATE";

// Built-in LED (many ESP32-S2 boards)
#define BLINK_GPIO GPIO_NUM_15

void app_main(void)
{
    ESP_LOGI(TAG, "ESP32-S2 Template Project Started!");
    ESP_LOGI(TAG, "SDK Version: %s", esp_get_idf_version());
    ESP_LOGI(TAG, "Chip: %s, Single Core", CONFIG_IDF_TARGET);

    // Configure LED GPIO
    gpio_reset_pin(BLINK_GPIO);
    gpio_set_direction(BLINK_GPIO, GPIO_MODE_OUTPUT);

    int level = 0;
    while (1) {
        ESP_LOGI(TAG, "ESP32-S2 running (USB OTG available)... LED: %s", level ? "ON" : "OFF");
        gpio_set_level(BLINK_GPIO, level);
        level = !level;
        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}
