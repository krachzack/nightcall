#!/usr/bin/env python3

import smbus
import atexit

class HardPhone:
    byte_unring = 0
    byte_ring = 1

    def __init__(self):
        self.address = 4
        self.bus = smbus.SMBus(1)
        atexit.register(self.unring)

    def ring(self):
        self.bus.write_byte(self.address, HardPhone.byte_ring)

    def unring(self):
        self.bus.write_byte(self.address, HardPhone.byte_unring)
