#!/bin/bash
#
# Ensures that pulseaudio, vlc and ntp are installed and configures everything
# so this device is set up to be used as a remote speaker for pulseaudio.
# The other end, where this script must also be run, should be in the environment
# variable NIGHTCALL_SINK_HOSTNAME. Be sure to set this variable so the
# pulseaudio cookie can be copied over from there for authentication.
#
# Per default, the first microphone of the second card (alsa://plughw:1,0) will
# be streamed in nightcall.sh. Override this by setting $NIGHTCALL_SOURCE_URL
# to something VLC can play.
#

# Configuration
# =============
# Other end of connection, defaults to zenzi.local.
# pulseaudio cookie will be loaded from there for authentication.
# Also this will be the target of playing the built-in microphone in the
# nightcall script.
NIGHTCALL_SINK_HOSTNAME=${NIGHTCALL_SINK_HOSTNAME:-zenzi.local}
PULSE_DEFAULT_PA="/etc/pulse/default.pa"
PULSE_UNIT_FILE="/etc/systemd/system/pulseaudio.service"
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
  echo "error: pulseuadio configuration failed, exiting. Cause: $1"
  exit 1
}

function uncomment {
  if [ ! -f "$1" ]; then
    bail "File does not exist, cannot uncomment: \"$1\""
  fi

  if [[ -z "${2// }" ]]; then
    bail "Pattern to uncomment in $1 was empty or only spaces: $2"
  fi

  sudo sed -i "/$2/s/^[;#]//g" $1
}

function patch_pulse_config {
  if [ ! -f "$PULSE_DEFAULT_PA" ]; then
    echo "Cannot find pulseaudio configuration."
    echo "Attempting to install pulseaudio, you may be asked for root privileges..."
    sudo apt-get install pulseaudio pulseaudio-module-zeroconf alsa-utils avahi-daemon || bail "Installing pulseaudio failed."

    if [ ! -f "$PULSE_DEFAULT_PA" ]; then
      bail "Installed pulseaudio, still cannot find $PULSE_DEFAULT_PA configuration file."
    fi
  fi

  echo "Patching $PULSE_DEFAULT_PA ..."
  uncomment $PULSE_DEFAULT_PA "module-native-protocol-tcp"
  uncomment $PULSE_DEFAULT_PA "module-zeroconf-publish"
}

function pull_pulse_cookie {
    if ask_consent "Will attempt to copy pulseaudio cookie from $NIGHTCALL_SINK_HOSTNAME. Continue?"
    then
      echo "Trying to copy pulseaudio cookie from $NIGHTCALL_SINK_HOSTNAME via scp..."
      echo "You will be asked to enter the remote password for permission."
      mkdir -p ~/.config/pulse && scp pi@$NIGHTCALL_SINK_HOSTNAME:~/.config/pulse/cookie ~/.config/pulse/cookie || bail "Failed to copy remote pulseaudio cookie."
      echo "Done copying pulseaudio cookie from $NIGHTCALL_SINK_HOSTNAME"
    else
      ask_consent "Continue without setting cookie?" || bail "Stopping at user request."
      echo "WARNING: No cookie copied. You should NOT skip this on the other machine or you are in deep shit."
    fi
}

function sync_time {
  if ! [ -x "$(command -v ntpq)" ]; then
    echo "Cannot find ntpq tool for timesync, trying to install NTP."
    sudo apt-get install ntp || bail "Could not install NTP."
  fi

  echo "NTP servers:"
  ntpq -p
}

function ensure_pulseaudio_running {
  if [ ! -f "$PULSE_UNIT_FILE" ]
  then
    echo "No pulseaudio unit file found at $PULSE_UNIT_FILE, creating it..."
    echo "You may be asked to authenticate..."

    sudo echo "[Unit]" > $PULSE_UNIT_FILE
    sudo echo "Description=PulseAudio Daemon" >> $PULSE_UNIT_FILE
    sudo echo "" >> $PULSE_UNIT_FILE
    sudo echo "[Install]" >> $PULSE_UNIT_FILE
    sudo echo "WantedBy=multi-user.target" >> $PULSE_UNIT_FILE
    sudo echo "" >> $PULSE_UNIT_FILE
    sudo echo "[Service]" >> $PULSE_UNIT_FILE
    sudo echo "Type=simple" >> $PULSE_UNIT_FILE
    sudo echo "PrivateTmp=true" >> $PULSE_UNIT_FILE
    sudo echo "ExecStart=/usr/bin/pulseaudio –system –realtime –disallow-exit –no-cpu-limit" >> $PULSE_UNIT_FILE

    echo "Enabling pulseaudio at startup..."
    sudo systemctl enable pulseaudio
  fi

  echo "Ensuring pulseaudio is running, this may require authentication..."
  sudo systemctl start pulseaudio
}

echo "Configuring pulseaudio..." && \
patch_pulse_config && \
pull_pulse_cookie && \
ensure_pulseaudio_running && \
sync_time && \
echo "Done, pulseaudio is configured and running."
