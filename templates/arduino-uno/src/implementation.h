/*
 * Arduino Uno - Blink Example (Arduino Framework)
 *
 * Hardware: Arduino Uno R3
 * MCU: ATmega328P (8-bit AVR @ 16 MHz)
 *
 * This demonstrates the classic "Hello World" for embedded systems:
 * Blinks the built-in LED and prints messages to serial.
 *
 * Blink rate: 1 second on / 1 second off
 */

#include <Arduino.h>

// Built-in LED on Arduino Uno is on pin 13
#define LED_PIN 13

void setup() {
  // Initialize serial communication
  Serial.begin(9600);
  delay(100);  // Brief delay for serial to stabilize

  // Initialize LED pin as output
  pinMode(LED_PIN, OUTPUT);

  Serial.println();
  Serial.println("Arduino Uno Template Project Started!");
  Serial.println("Built-in LED will blink every second");
}

void loop() {
  // Turn LED on
  digitalWrite(LED_PIN, HIGH);
  Serial.println("LED ON");
  delay(1000);  // Wait 1 second

  // Turn LED off
  digitalWrite(LED_PIN, LOW);
  Serial.println("LED OFF");
  delay(1000);  // Wait 1 second
}
