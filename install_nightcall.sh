NIGHTCALL_UNIT_FILE="/etc/systemd/system/nightcall.service"

echo "Adding nightcall unit file, this may reuire authentication..."
sudo bash -c "cat <<< '
[Unit]
Description=nightcall

[Install]
WantedBy=multi-user.target

[Service]
User=pi
Type=simple
PrivateTmp=true
ExecStart=/home/pi/nightcall/nightcall.sh
' > $NIGHTCALL_UNIT_FILE"

echo "Enabling nightcall at startup, this may require authentication..."
sudo systemctl daemon-reload
sudo systemctl enable nightcall

echo "Ensuring nightcall is running..."
sudo systemctl start nightcall
