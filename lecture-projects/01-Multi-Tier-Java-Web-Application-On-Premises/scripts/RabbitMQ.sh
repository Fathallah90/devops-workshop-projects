#!/bin/bash
set -euo pipefail

# Validate root privileges
if [[ $EUID -ne 0 ]]; then
	echo "ERROR: Run as root or use sudo."
	exit 1
fi

echo "Updating packages and installing dependencies..."
dnf install -y epel-release wget

# Configure RabbitMQ repository
dnf install -y centos-release-rabbitmq-38

# Install RabbitMQ server
dnf --enablerepo=centos-rabbitmq-38 install -y rabbitmq-server

# Enable and start RabbitMQ
systemctl enable --now rabbitmq-server

# Validate service
if ! systemctl is-active --quiet rabbitmq-server; then
	echo "ERROR: RabbitMQ failed to start."
	systemctl status rabbitmq-server --no-pager
	exit 1
fi

# Configure remote access for users
mkdir -p /etc/rabbitmq
cat >/etc/rabbitmq/rabbitmq.config <<'EOF'
[{rabbit, [{loopback_users, []}]}].
EOF

# Create user if it doesn't already exist
if rabbitmqctl list_users | awk '{print $1}' | grep -qx 'test'; then
	echo "User 'test' already exists."
else
	rabbitmqctl add_user test test
fi

# Grant administrator privileges
rabbitmqctl set_user_tags test administrator

# Restart and validate RabbitMQ
systemctl restart rabbitmq-server

if systemctl is-active --quiet rabbitmq-server; then
	echo "SUCCESS: RabbitMQ is running."
	rabbitmqctl list_users
	systemctl status rabbitmq-server --no-pager
else
	echo "ERROR: RabbitMQ failed after configuration."
	exit 1
fi

echo "RabbitMQ installation and configuration completed."
