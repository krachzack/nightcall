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
PULSE_CLIENT_CONF="/etc/pulse/client.conf"
APT_DEPENDENCIES="pulseaudio pulseaudio-module-zeroconf alsa-utils avahi-daemon espeak sox"
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
    sudo apt-get install $APT_DEPENDENCIES || bail "Installing pulseaudio failed."

    if [ ! -f "$PULSE_DEFAULT_PA" ]; then
      bail "Installed pulseaudio, still cannot find $PULSE_DEFAULT_PA configuration file."
    fi
  fi

  echo "Patching $PULSE_DEFAULT_PA ..."
  uncomment $PULSE_DEFAULT_PA "module-native-protocol-tcp"
  uncomment $PULSE_DEFAULT_PA "module-zeroconf-publish"
  # sudo bash -c "echo 'resample-method = speex-float-3' >> $PULSE_DEFAULT_PA"

  # Add sink for remote stream so it can be muted
  if ! grep sink_name=nirvana "$PULSE_DEFAULT_PA"
  then
    sudo bash -c "echo 'load-module module-null-sink sink_name=nirvana sink_properties=device.description=\"Nirvana\"' >> $PULSE_DEFAULT_PA"
    #sudo bash -c "echo 'load-module module-loopback source=remotephone.monitor sink=alsa_output.usb-C-Media_Electronics_Inc._USB_Audio_Device-00.analog-stereo latency_msec=50' >> $PULSE_DEFAULT_PA"
  fi

  # Disable autospawn if not already disabled
  if ! grep autospawn=no "$PULSE_CLIENT_CONF"
  then
    echo "Patching $PULSE_CLIENT_CONF ..."
    sudo bash -c "echo 'autospawn=no' >> $PULSE_CLIENT_CONF"
    sudo bash -c "echo 'auto-connect-localhost=yes' >> $PULSE_CLIENT_CONF"

    if ask_consent "Should I set default-sink and default-source to our USB dongle?"
    then
      sudo bash -c "echo 'default-sink = alsa_output.usb-C-Media_Electronics_Inc._USB_Audio_Device-00.analog-stereo' >> $PULSE_CLIENT_CONF"
      sudo bash -c "echo 'default-source = alsa_input.usb-C-Media_Electronics_Inc._USB_Audio_Device-00.analog-mono' >> $PULSE_CLIENT_CONF"
    fi
    # sudo bash -c "echo 'default-server=127.0.0.1' >> $PULSE_CLIENT_CONF"
  fi

  if ! grep 'mkdir $XDG_RUNTIME_DIR/pulse' ~/.bashrc
  then
    echo "Patching .bashrc"
    echo 'if [ ! -d "$XDG_RUNTIME_DIR/pulse" ]; then' >> ~/.bashrc
    echo '    mkdir $XDG_RUNTIME_DIR/pulse && sudo mount --bind $(readlink /home/pi/.config/pulse/$(cat /etc/machine-id)-runtime) $XDG_RUNTIME_DIR/pulse' >> ~/.bashrc
    echo 'fi' >> ~/.bashrc
  fi
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

    sudo mv pulseaudio.service $PULSE_UNIT_FILE

    echo "export PULSE_COOKIE=\"/home/pi/.config/pulse/cookie\"" >> ~/.bashrc

    echo "Enabling pulseaudio at startup..."
    sudo systemctl daemon-reload
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
