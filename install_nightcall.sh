NIGHTCALL_UNIT_FILE="/etc/systemd/system/nightcall.service"

sudo apt-get install vlc-nox sox

echo "Adding nightcall unit file, this may reuire authentication..."
sudo mv nightcall.service $NIGHTCALL_UNIT_FILE

echo "Enabling nightcall at startup, this may require authentication..."
sudo systemctl daemon-reload
sudo systemctl enable nightcall

echo "Ensuring nightcall is running..."
sudo systemctl start nightcall
