import smbus
import atexit

class HardPhone:
    byte_request_unring = 0
    byte_request_ring = 1
    byte_response_hangup = 11
    byte_response_pickup = 12

    def __init__(self):
        self.address = 4
        self.bus = smbus.SMBus(1)
        self.picked_up = False
        self.last_typed = -1
        atexit.register(self.unring)

    def is_picked_up(self):
        return self.picked_up

    def ring(self):
        self.bus.write_byte(self.address, HardPhone.byte_request_ring)

    def unring(self):
        self.bus.write_byte(self.address, HardPhone.byte_request_unring)

    def type(self, number):
        self.last_typed = number
        print('Typed %d.' % (self.last_typed))

    def read(self):
        msg = self.bus.read_byte(self.address)
        if msg == HardPhone.byte_response_hangup:
            self.picked_up = False
            print("Hung up")
        elif msg == HardPhone.byte_response_pickup:
            self.picked_up = True
            print("Picked up")
        elif msg >= 0 and msg <= 9:
            self.type(msg)
        else:
            print('Phone said %d.' % (msg))
