#!/usr/bin/env python3

import RPi.GPIO as GPIO
import time

class Lights:
    light_pin = 17

    def __init__(self):
        self.enabled = False
        GPIO.setmode(GPIO.BCM)
        GPIO.setup(Lights.light_pin, GPIO.OUT, initial=GPIO.LOW)

    def is_on(self):
        return self.enabled

    def set_enabled(self, val):
        self.enabled = val is True
        self.flush()

    def toggle(self):
        self.set_enabled(not self.enabled)

    def on(self):
        self.set_enabled(True)

    def off(self):
        self.set_enabled(False)

    def flush(self):
        GPIO.output(Lights.light_pin, self.enabled)

if __name__ == '__main__':
    lights = Lights()
    while True:
        lights.on()
        time.sleep(0.5)
        lights.off()
        time.sleep(0.3)
