#!/bin/bash

# Common configuration
# ====================
STREAM_URL="alsa://plughw:1,0" # Alsa microphone to stream from
APT_GET_DEPS="vlc-nox"         # These space-separated packages will be installed if the VLC tool cvlc is not available
SAMPLING_RATE=12000
KBPS="16k"
# Caching on receiving end in millisconds
RECEIVE_CACHE_MS=100
# Microphone caching before sending in millisconds
SEND_CACHE_MS=100

if [ "$HOSTNAME" = zenzi ]; then
    # zenzi only configuration
    # ========================
    echo "Running nightcall on zenzi..."
    STREAM_NAME="ZenziToRudi"
    STREAM_TARGET_ADDR="rudi.local"
    STREAM_LISTEN_PORT="5004"
    STREAM_TARGET_PORT="5004"
else
    # rudi only configuration
    # =======================
    echo "Running nightcall on rudi..."
    STREAM_NAME="RudiToZenzi"
    STREAM_TARGET_ADDR="zenzi.local"
    STREAM_LISTEN_PORT="5004"
    STREAM_TARGET_PORT="5004"
fi

# Ensure VLC is installed
if ! [ -x "$(command -v cvlc)" ]; then
  echo 'Error: vlc is not installed, updating packages and installing now. Please enter root password.' >&2

  # Run in subshell so only one sudo is required regardless of how long the commands take
  sudo bash -c "apt-get update && apt-get upgrade && apt-get install $APT_GET_DEPS"
fi

# cd into script directory
cd "$(dirname "$0")"

# Start receiving stream in the background
cvlc rtp://@:$STREAM_LISTEN_PORT \
  --network-caching=$RECEIVE_CACHE_MS \
  --rtsp-caching=$RECEIVE_CACHE_MS &

# Stream as 8kbps MP3
cvlc -vvv $STREAM_URL --repeat \
  --file-caching=$SEND_CACHE_MS \
  --live-caching=$SEND_CACHE_MS \
  --rtsp-caching=$SEND_CACHE_MS \
  --network-caching=$SEND_CACHE_MS \
  --sout="#transcode{vcodec=none,acodec=mp3,ab=$KBPS,samplerate=$SAMPLING_RATE,channels=1}:rtp{dst=$STREAM_TARGET_ADDR,port=$STREAM_TARGET_PORT,name=$STREAM_NAME,ttl=3,mux=ts,sdp=sap}"
