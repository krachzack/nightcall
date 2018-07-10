#!/bin/bash
#
# Starts streaming to $NIGHTCALL_SINK_HOSTNAME.
# The first microphone of the second card (alsa://plughw:1,0) will be streamed.
# Override this by setting $NIGHTCALL_SOURCE_URL to something VLC can play.
#

# Configuration
# =============
# First play some test things to show we are ready
# Stream $NIGHTCALL_SOURCE_URL to $NIGHTCALL_SINK_HOSTNAME or default to
# streaming first microphone of second card (plughw:1,0)
NIGHTCALL_SOURCE_URL=${NIGHTCALL_SOURCE_URL:-alsa://plughw:1,0}
# A wav file to play to the other end as a means of checking whether it
# works.
NIGHTCALL_READY_SOURCE_URL=${NIGHTCALL_READY_SOURCE_URL:-/home/pi/nightcall/beep.wav}
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

function await_mdns {
  echo "Waiting until $NIGHTCALL_SINK_HOSTNAME can be resolved in the network..."
  while ! getent hosts $NIGHTCALL_SINK_HOSTNAME
  do
    echo "Cannot resolve $NIGHTCALL_SINK_HOSTNAME yet, waiting 5 seconds and trying again"
    sleep 5
  done
}

function await_ping {
  echo "Waiting until $NIGHTCALL_SINK_HOSTNAME becomes reachable via ping..."
  # Wait a million seconds or until 10 packets received
  ping -c 10 -w 1000000 $NIGHTCALL_SINK_HOSTNAME > /dev/null
}

function await_streaming {
  echo "Waiting streaming a static WAV file to $NIGHTCALL_SINK_HOSTNAME succeeds..."
  while cvlc $NIGHTCALL_READY_SOURCE_URL vlc://quit 2>&1 >/dev/null | grep -q 'PulseAudio server connection failure'
  do
    echo "Reachable via ping, but streaming does not work yet, waiting 5 seconds before trying again"
    sleep 5
  done
}

# Streams $NIGHTCALL_SOURCE_URL and restarts if error seen or vlc exits
function keep_streaming {
  LOG="/tmp/nightcall-pacat-microphone-stream.log"
  MATCH="error"

  pacat -r --rate=8000 --server=$NIGHTCALL_SINK_HOSTNAME --volume=65536 --latency-msec=200 --process-time-msec=200 | pacat -p --rate=8000 --volume=65536 --latency-msec=200 --process-time-msec=200 --client-name=remotephone --stream-name=remotephone --server=127.0.0.1 > "$LOG" 2>&1 &
  PID=$!

  while sleep 3
  do
      # If prints something about a pulse error, kill it
      if fgrep --quiet "$MATCH" "$LOG"
      then
        echo "pacat reported error, killing it..."
        kill $PID
        PID=0
      fi

      # In any case, if it is dead now, restart it
      # This also restarts pacat if the playlist is over
      if ! ps -p $PID > /dev/null
      then
        echo "Restarting script after pacat exit..."
        sleep 5
        exec /home/pi/nightcall/nightcall.sh
      fi
  done
}

export PULSE_SERVER=$NIGHTCALL_SINK_HOSTNAME

echo "Pumping up the volume..."
pump_up_the_volume

await_mdns
await_ping
# await_streaming

echo "Sending $NIGHTCALL_SOURCE_URL to $NIGHTCALL_SINK_HOSTNAME..."
ensure_vlc_installed && \
await_streaming && \
keep_streaming
# Play beep sound locally to signify that other end could be pinged
# cvlc /home/pi/nightcall/beep.wav vlc://quit && \
# Then play microphone remotely
