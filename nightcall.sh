#!/bin/bash
#
# Starts streaming to $NIGHTCALL_SINK_HOSTNAME.
# The first microphone of the second card (alsa://plughw:1,0) will be streamed.
# Override this by setting $NIGHTCALL_SOURCE_URL to something VLC can play.
#

# Configuration
# =============
# Stream $NIGHTCALL_SOURCE_URL to $NIGHTCALL_SINK_HOSTNAME or default to
# streaming first microphone of second card (plughw:1,0)
NIGHTCALL_SOURCE_URL=${NIGHTCALL_SOURCE_URL:-alsa://plughw:1,0}
# Other end of connection, defaults to zenzi.local.
# pulseaudio cookie will be loaded from there for authentication.
# Also this will be the target of playing the built-in microphone
NIGHTCALL_SINK_HOSTNAME=${NIGHTCALL_SINK_HOSTNAME:-zenzi.local}
# ============

function ask_consent {
  QUESTION=${1:-Dangerous stuff ahead. Continue anyway?}
  read -p "$QUESTION [Y/n]" -r
  if [[ $REPLY != "Y" ]]
  then
    return 1 # Non-zero, erroneous
  else
    return 0
  fi
}

function bail {
  echo "error: nightcall failed, exiting. Cause: $1"
  exit 1
}

function ensure_vlc_installed {
  if ! [ -x "$(command -v cvlc)" ]; then
    echo "cvlc not found, attempting to install vlc-nox now..."

    # Run in subshell so only one sudo is required regardless of how long the commands take
    sudo apt-get install vlc-nox || bail "Failed to install vlc."
  fi
}

function pump_up_the_volume {
  amixer set Master -- 100%
  amixer set Capture -- 100%
}

echo "Pumping up the volume..."
pump_up_the_volume

echo "Waiting until $NIGHTCALL_SINK_HOSTNAME becomes reachable via ping..."
while ! ping -c1 $NIGHTCALL_SINK_HOSTNAME &>/dev/null; do echo "Not reachable yet, waiting 5 seconds" && sleep 5; done

echo "Sending microphone to $NIGHTCALL_SINK_HOSTNAME..."
ensure_vlc_installed && \
PULSE_SERVER=$NIGHTCALL_SINK_HOSTNAME cvlc $NIGHTCALL_SOURCE_URL
