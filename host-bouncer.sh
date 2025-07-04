#!/bin/bash

# Install CrowdSec firewall bouncer
echo "Installing CrowdSec firewall bouncer..."
curl -s https://install.crowdsec.net | sudo sh

sudo apt install crowdsec-firewall-bouncer-iptables

# Configure the bouncer
echo ""
echo "=== CrowdSec Firewall Bouncer Configuration ==="
echo ""
echo "The bouncer needs an API key to connect to your CrowdSec instance."
echo "You can find this key in your Docker .env file as CROWDSEC_BOUNCER_KEY_HOST"
echo "or generate a new one with: docker exec -it crowdsec cscli bouncers add host-bouncer"
echo ""

# Ask for the API key
read -p "Enter your CrowdSec API key: " API_KEY

if [ -z "$API_KEY" ]; then
    echo "Error: API key cannot be empty"
    exit 1
fi

# Ask for the API URL
read -p "Enter your CrowdSec API URL [default: http://127.0.0.1:9000/]: " API_URL
API_URL=${API_URL:-http://127.0.0.1:9000/}

# Update the configuration file
echo "Updating configuration file..."
sudo sed -i "s|api_key: .*|api_key: $API_KEY|" /etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml
sudo sed -i "s|api_url: .*|api_url: $API_URL|" /etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml

# Restart the service
echo "Restarting CrowdSec firewall bouncer service..."
sudo systemctl restart crowdsec-firewall-bouncer.service

# Check if the service is running
if sudo systemctl is-active --quiet crowdsec-firewall-bouncer.service; then
    echo "CrowdSec firewall bouncer is now running and configured!"
    echo "You can check its status with: sudo systemctl status crowdsec-firewall-bouncer.service"
else
    echo "Error: CrowdSec firewall bouncer service failed to start."
    echo "Check the logs with: sudo journalctl -u crowdsec-firewall-bouncer.service"
fi
