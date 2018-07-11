#!/bin/bash

PHONECTL_UNIT_FILE="/etc/systemd/system/phonectl.service"

echo "Installing dependencies, this may reuire authentication..."
sudo apt-get install sox espeak python3-smbus python3-rpi.gpio

echo "Adding phonectl unit file, this may reuire authentication..."
sudo mv phonectl.service $PHONECTL_UNIT_FILE

echo "Enabling phonectl at startup, this may require authentication..."
sudo systemctl daemon-reload
sudo systemctl enable phonectl

echo "Ensuring phonectl is running..."
sudo systemctl start phonectl
