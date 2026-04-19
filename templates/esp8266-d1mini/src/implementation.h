/*
 * ESP D1 Mini (ESP8266MOD) - LED Blink Example
 *
 * Hardware: Wemos D1 Mini
 * MCU: ESP8266MOD (Xtensa L106 @ 80 MHz)
 *
 * Built-in LED: GPIO2 (labelled D4 on the board)
 * The built-in LED is ACTIVE LOW — setting the pin LOW turns the LED ON.
 *
 * Blink rate: 500 ms on / 500 ms off (1 Hz)
 */

#include <Arduino.h>

#define LED_PIN 2  // D4 on D1 Mini silkscreen (GPIO2)

void setup() {
  // Initialize serial communication
  Serial.begin(115200);
  delay(100);  // Brief delay for serial to stabilize

  Serial.println();
  Serial.println("ESP D1 Mini - LED Blink Started");
  Serial.print("Chip ID: ");
  Serial.println(ESP.getChipId(), HEX);
  Serial.println("Built-in LED on GPIO2 (D4) - active LOW");

  // Set LED pin as output
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, HIGH);  // Start with LED OFF (active LOW)
}

void loop() {
  // Turn LED ON (drive LOW)
  digitalWrite(LED_PIN, LOW);
  Serial.println("LED ON");
  delay(500);

  // Turn LED OFF (drive HIGH)
  digitalWrite(LED_PIN, HIGH);
  Serial.println("LED OFF");
  delay(1500);
}
