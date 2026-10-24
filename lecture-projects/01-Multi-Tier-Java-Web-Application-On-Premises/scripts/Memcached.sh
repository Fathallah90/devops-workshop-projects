#!/bin/bash
set -euo pipefail

echo "===== Memcached Installation ====="

# 1. Validate root privileges
if [[ $EUID -ne 0 ]]; then
	echo "ERROR: Run this script as root or using sudo."
	exit 1
fi

# 2. Validate package manager
if command -v dnf &>/dev/null; then
	PKG="dnf"
elif command -v yum &>/dev/null; then
	PKG="yum"
else
	echo "ERROR: Neither dnf nor yum is available."
	exit 1
fi

# 3. Update system packages
echo "Updating system packages..."
"$PKG" update -y

# 4. Install EPEL (optional) and Memcached
echo "Installing Memcached..."
"$PKG" install -y epel-release || echo "EPEL unavailable; continuing..."

"$PKG" install -y memcached

# 5. Validate configuration file
CONFIG="/etc/sysconfig/memcached"

if [[ ! -f "$CONFIG" ]]; then
	echo "ERROR: $CONFIG not found."
	exit 1
fi

# 6. Back up and configure listening address
cp -n "$CONFIG" "${CONFIG}.bak"

sed -i 's/127\.0\.0\.1/0.0.0.0/g' "$CONFIG"

# 7. Start and enable service
echo "Starting and enabling Memcached..."
systemctl enable --now memcached
systemctl restart memcached

# 8. Validate service status
if systemctl is-active --quiet memcached; then
	echo "SUCCESS: Memcached is running."
else
	echo "ERROR: Memcached failed to start."
	systemctl status memcached --no-pager
	exit 1
fi

# 9. Validate port 11211
if command -v ss &>/dev/null &&
	ss -lnt | grep -qE '0\.0\.0\.0:11211|\\*:11211'; then
	echo "SUCCESS: Memcached is listening on port 11211."
else
	echo "WARNING: Port 11211 is not confirmed listening on all IPv4 interfaces."
	ss -lntp | grep 11211 || true
fi

echo "===== Installation Complete ====="
systemctl status memcached --no-pager
