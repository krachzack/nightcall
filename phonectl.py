#!/usr/bin/env python3

import subprocess
import atexit
import hardphone
import time
import hardphone
import lights
import socket
import os
import signal

class PhoneCtl:
    cycle_secs = 0.1
    state_mute = 'mute'
    state_ring = 'ring'
    state_listen = 'listen'
    state_beep = 'beep'
    udp_port = 18242
    udp_msg_picked_up = 'picked_up'
    udp_msg_hung_up = 'hung_up'
    lights_toggle_on_time = 0.5
    lights_toggle_off_time = 0.3
    ring_toggle_on_time = 1.5
    ring_toggle_off_time = 2.5
    ring_max_time = 60.0
    """ When hanging up on an open call and the other end does not, do not ring again for the next three seconds """
    ring_hangup_disable_time = 6.0

    def __init__(self):
        self.state = PhoneCtl.state_mute
        self.process = None
        self.lights = lights.Lights()
        self.phone = hardphone.HardPhone()
        self.udp_endpoint = (os.environ['NIGHTCALL_SINK_HOSTNAME'], PhoneCtl.udp_port)
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.setblocking(False)
        self.sock.bind((os.environ['NIGHTCALL_LISTEN_IP'], PhoneCtl.udp_port))
        atexit.register(self.sock.close)
        self.remote_picked_up = False
        atexit.register(self.mute)
        self.last_me_ready = False
        self.light_toggle_timeout = None
        self.ring_stop_time = None
        self.ring_toggle_timeout = None
        self.ring_disabled_time = None

    def run(self):
        while True:
            time_cycle_start = time.time()
            self.update()
            time_cycle_end = time.time()
            sync_time = PhoneCtl.cycle_secs - (time_cycle_end - time_cycle_start)
            if sync_time > 0:
                time.sleep(sync_time)

    def update(self):
        self.recv_remote_phone_state()
        self.phone.read()
        self.send_local_phone_state_to_remote()
        self.update_state()
        self.update_lights()
        self.update_ring()

    def update_lights(self):
        if self.ring_stop_time is not None and time.time() > self.ring_stop_time:
            self.lights.on()
            return

        if self.light_toggle_timeout is None:
            self.lights.on()
        else:
            self.light_toggle_timeout = self.light_toggle_timeout - PhoneCtl.cycle_secs
            if self.light_toggle_timeout < 0:
                if self.lights.is_on():
                    self.light_toggle_timeout = PhoneCtl.lights_toggle_off_time
                    self.lights.off()
                else:
                    self.light_toggle_timeout = PhoneCtl.lights_toggle_on_time
                    self.lights.on()

    def update_ring(self):
        if self.ring_disabled_time is not None and (time.time() - self.ring_disabled_time) < PhoneCtl.ring_hangup_disable_time or self.ring_stop_time is not None and time.time() > self.ring_stop_time:
            self.phone.unring()
            return

        if self.ring_toggle_timeout is None:
            self.phone.unring()
        else:
            self.ring_toggle_timeout = self.ring_toggle_timeout - PhoneCtl.cycle_secs
            if self.ring_toggle_timeout < 0:
                if self.phone.is_ringing():
                    self.ring_toggle_timeout = PhoneCtl.ring_toggle_off_time
                    self.phone.unring()
                else:
                    self.ring_toggle_timeout = PhoneCtl.ring_toggle_on_time
                    self.phone.ring()

    def recv_remote_phone_state(self):
        try:
            data, addr = self.sock.recvfrom(64)
            data = data.decode()
            print("UDP data: %s" % (data))
            if data == PhoneCtl.udp_msg_picked_up:
                if self.remote_picked_up == False:
                    print("Remote picked up")
                self.remote_picked_up = True
            elif data == PhoneCtl.udp_msg_hung_up:
                if self.remote_picked_up == True:
                    print("Remote hung up")
                self.remote_picked_up = False
            else:
                print("Unknown message received over UDP %s from %s" % (data, addr))
        except OSError as msg:
            print("UDP error: %s" % (msg))

    def send_local_phone_state_to_remote(self):
        if self.phone.is_picked_up():
            self.sock.sendto(PhoneCtl.udp_msg_picked_up.encode(), self.udp_endpoint)
        else:
            self.sock.sendto(PhoneCtl.udp_msg_hung_up.encode(), self.udp_endpoint)

    def update_state(self):
        me_ready = self.phone.is_picked_up()
        you_ready = self.remote_picked_up
        if me_ready and you_ready:
            self.listen()
        elif me_ready and not you_ready:
            self.beep()
        elif you_ready and not me_ready:
            self.ring()
        else:
            self.mute()

        self.last_me_ready = me_ready

    def change_state(self, new_state, command):
        old_state = self.state
        if new_state != old_state:
            # Terminate what was playing before
            if self.process is not None:
                os.killpg(os.getpgid(self.process.pid), signal.SIGTERM)
                self.process = None

            # Start playing, if anything
            if command is not None:
                self.process = self.spawn_forever(command)

            # And tell phone whether to ring
            if new_state == PhoneCtl.state_ring:
                self.phone.ring()
                self.lights.off()
                self.light_toggle_timeout = PhoneCtl.lights_toggle_off_time
                self.ring_toggle_timeout = PhoneCtl.ring_toggle_on_time
                self.ring_stop_time = time.time() + PhoneCtl.ring_max_time
                if old_state == PhoneCtl.state_listen:
                    self.ring_disabled_time = time.time()
            else:
                self.phone.unring()
                self.light_toggle_timeout = None
                self.ring_toggle_timeout = None
                self.ring_stop_time = None

            # And set to the new state
            self.state = new_state

    # Runs a process forever (Until killed)
    def spawn_forever(self, cmd):
        return subprocess.Popen(cmd, shell=True, preexec_fn=os.setsid)

    def mute(self):
        self.change_state(PhoneCtl.state_mute, None)

    def beep(self):
        self.change_state(PhoneCtl.state_beep, 'while true; do paplay ~/nightcall/beep.wav  --volume=65536 --latency-msec=200 --process-time-msec=200 --client-name=phonering --stream-name=phonering --server=127.0.0.1; sleep 0.5s; done')

    def ring(self):
        self.change_state(PhoneCtl.state_ring, None)

    def listen(self):
        self.change_state(PhoneCtl.state_listen, 'pacat -r --rate=8000 --server=$NIGHTCALL_SINK_HOSTNAME --volume=65536 --latency-msec=200 --process-time-msec=200 | pacat -p --rate=8000 --volume=65536 --latency-msec=200 --process-time-msec=200 --client-name=phonelisten --stream-name=phonelisten --server=127.0.0.1')

# If called as script, run forever
if __name__ == '__main__':
    PhoneCtl().run()
