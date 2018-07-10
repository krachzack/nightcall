#!/bin/sh
STREAM_IDX=$(pactl list sink-inputs | grep 'application.name = "remotephone"' -B 16 | cut -d ' ' -f 3 | head -n 1 | cut -c 2-)
pactl move-sink-input $STREAM_IDX alsa_output.usb-C-Media_Electronics_Inc._USB_Audio_Device-00.analog-stereo
