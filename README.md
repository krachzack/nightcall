# nightcall
Direct line for speech between two Raspberries.

## Preparation
Be sure SSH is enabled on both your raspberries and that they can reach each
other over the network.

## Configuration
Globally set the environment variable `NIGHTCALL_SINK_HOSTNAME` to the hostname
of the other end. For historical reasons, this will default to `zenzi.local`.

If you want to stream something other than `alsa://plughw:1,0`, that is the first
microphone of the second soundcard, set the environment variable
`NIGHTCALL_SOURCE_URL` to something VLC can play.

## Running
Everything set up? Run `./nightcall.sh` on both devices to set up everything and
start streaming. This will take a while on the first run, since pulseaudio, VLC
and NTP have to be installed first, unless you already did so.

Apart from installing the necessary packages, this will set the local pulseaudio
cookie to the cookie of `NIGHTCALL_SINK_HOSTNAME` over scp, requiring you to
login on the remote machine via SSH.

Run `nightcall.sh` to set up pulseaudio, vlc
