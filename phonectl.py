#!/usr/bin/env python

import subprocess

class PhoneCtl:
    state_mute = 'mute'
    state_ring = 'ring'
    state_listen = 'listen'

    def __init__(self):
        self.state = PhoneCtl.state_mute
        self.process = None

    def update_state(self, new_state, command):
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
        self.update_state(PhoneCtl.state_mute, None)

    def ring(self):
        self.update_state(PhoneCtl.state_ring, 'say ring')

    def listen(self):
        self.update_state(PhoneCtl.state_listen, 'say listen')
