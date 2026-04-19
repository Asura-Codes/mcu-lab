#include <stdio.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "driver/gpio.h"
#include "esp_log.h"

#define LED_GPIO 8

static const char *TAG = "ESP32-C3";

void app_main(void)
{
    ESP_LOGI(TAG, "ESP32-C3 Started!");
    ESP_LOGI(TAG, "Configuring LED on GPIO %d", LED_GPIO);

    gpio_reset_pin(LED_GPIO);
    gpio_set_direction(LED_GPIO, GPIO_MODE_OUTPUT);

    int count = 0;
    while (1) {
        gpio_set_level(LED_GPIO, 0);  // on (active-low)
        ESP_LOGI(TAG, "LED ON (and count: %d)", count);
        vTaskDelay(100 / portTICK_PERIOD_MS);

        gpio_set_level(LED_GPIO, 1);  // off
        ESP_LOGI(TAG, "LED OFF (and count: %d)", count);
        vTaskDelay(100 / portTICK_PERIOD_MS);

        count++;
    }
}
