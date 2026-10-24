#!/bin/bash

set -e

# Check root privileges
if [[ $EUID -ne 0 ]]; then
	echo "Error: Run this script as root or using sudo."
	exit 1
fi

# Validate OS
if ! command -v apt >/dev/null 2>&1; then
	echo "Error: This script requires a Debian/Ubuntu system."
	exit 1
fi

# Update OS
echo "Updating OS packages..."
apt update
DEBIAN_FRONTEND=noninteractive apt upgrade -y

# Install Nginx
echo "Installing Nginx..."
apt install nginx -y

# Validate installation
if ! command -v nginx >/dev/null 2>&1; then
	echo "Error: Nginx installation failed."
	exit 1
fi

# Create Nginx configuration
echo "Creating Nginx configuration..."

cat >/etc/nginx/sites-available/vproapp <<'EOF'
upstream vproapp {
    server app01:8080;
}

server {
    listen 80;

    location / {
        proxy_pass http://vproapp;
    }
}
EOF

# Disable default configuration
rm -f /etc/nginx/sites-enabled/default

# Enable vproapp configuration
ln -sfn /etc/nginx/sites-available/vproapp \
	/etc/nginx/sites-enabled/vproapp

# Validate Nginx configuration
echo "Testing Nginx configuration..."
nginx -t

# Enable and restart Nginx
systemctl enable nginx
systemctl restart nginx

# Validate service
if systemctl is-active --quiet nginx; then
	echo "Success: Nginx is installed and running."
else
	echo "Error: Nginx failed to start."
	exit 1
fi

echo "Reverse proxy configured: Nginx -> app01:8080"
