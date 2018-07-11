#!/usr/bin/env python3

import subprocess
import atexit
import hardphone
import time

class PhoneCtl:
    state_mute = 'mute'
    state_ring = 'ring'
    state_listen = 'listen'
    state_beep = 'beep'

    def __init__(self):
        self.state = PhoneCtl.state_mute
        self.process = None
        self.phone = HardPhone()
        atexit.register(self.mute)

    def run(self):
        while True:
            self.update()
            time.sleep(0.1)

    def update(self):
        self.phone.read()
        if self.phone.is_picked_up():
            self.beep()
        else:
            self.mute()

    def change_state(self, new_state, command):
        if new_state != self.state:
            # Terminate what was playing before
            if self.process is not None:
                self.process.terminate()

            # Start playing, if anything
            if command is not None:
                self.process = self.spawn_forever(command)

            # And set to the new state
            self.state = new_state

    # Runs a process forever (Until killed)
    def spawn_forever(self, cmd):
        forever_cmd = [
            '/bin/bash',
            '-c',
            'while true; do ' + cmd + '; sleep 0.5s; done'
        ]
        return subprocess.Popen(forever_cmd)

    def mute(self):
        self.change_state(PhoneCtl.state_mute, None)

    def beep(self):
        self.change_state(PhoneCtl.state_beep, 'paplay ~/nightcall/beep.wav  --volume=65536 --latency-msec=200 --process-time-msec=200 --client-name=phonering --stream-name=phonering --server=127.0.0.1')

    def ring(self):
        self.change_state(PhoneCtl.state_ring, 'paplay ~/nightcall/beep.wav  --volume=65536 --latency-msec=200 --process-time-msec=200 --client-name=phonering --stream-name=phonering --server=127.0.0.1')

    def listen(self):
        self.change_state(PhoneCtl.state_listen, 'pacat -r --rate=8000 --server=$NIGHTCALL_SINK_HOSTNAME --volume=65536 --latency-msec=200 --process-time-msec=200 | pacat -p --rate=8000 --volume=65536 --latency-msec=200 --process-time-msec=200 --client-name=phonelisten --stream-name=phonelisten --server=127.0.0.1')

# If called as script, run forever
if __name__ == '__main__':
    PhoneCtl().run()
