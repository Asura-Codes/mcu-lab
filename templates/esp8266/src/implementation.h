/*
 * ESP8266 - Hello World Example
 *
 * Hardware: Generic ESP8266 module
 * MCU: Xtensa L106 @ 80 MHz
 *
 * This example prints "Hello from ESP8266!" to the serial output
 * every second using the ESP8266 Arduino core.
 */

#include <Arduino.h>

void setup() {
  // Initialize serial communication
  Serial.begin(115200);
  delay(100);  // Brief delay for serial to stabilize

  Serial.println();
  Serial.println("ESP8266 Template Project Started!");
  Serial.print("Chip ID: ");
  Serial.println(ESP.getChipId(), HEX);
  Serial.print("Flash Chip Size: ");
  Serial.println(ESP.getFlashChipSize());
  Serial.print("Free Heap: ");
  Serial.println(ESP.getFreeHeap());
}

void loop() {
  Serial.println("Hello from ESP8266!");
  delay(1000);  // Wait 1 second
}
