#!/bin/sh
STREAM_IDX=$(pactl list sink-inputs | grep 'application.name = "remotephone"' -B 16 | cut -d ' ' -f 3 | head -n 1 | cut -c 2-)
pactl move-sink-input $STREAM_IDX nirvana
