#!/bin/bash
set -e

# Validate root privileges
if [ "$EUID" -ne 0 ]; then
	echo "ERROR: Run this script as root or using sudo."
	exit 1
fi

# Install Java if missing
if ! command -v java &>/dev/null; then
	echo "Java is not installed. Installing Java 11..."

	if command -v dnf &>/dev/null; then
		dnf install -y java-11-openjdk java-11-openjdk-devel
	elif command -v yum &>/dev/null; then
		yum install -y java-11-openjdk java-11-openjdk-devel
	else
		echo "ERROR: Neither dnf nor yum is available."
		exit 1
	fi
else
	echo "Java is already installed."
fi

# Validate Java installation
if ! command -v java &>/dev/null; then
	echo "ERROR: Java installation failed."
	exit 1
fi

# Variables
VERSION="9.0.75"
ARCHIVE="apache-tomcat-${VERSION}.tar.gz"
URL="https://archive.apache.org/dist/tomcat/tomcat-9/v${VERSION}/bin/${ARCHIVE}"
INSTALL_DIR="/usr/local/tomcat"

# Download Tomcat
cd /tmp

if [ ! -f "$ARCHIVE" ]; then
	echo "Downloading Tomcat..."
	wget -q --show-progress "$URL" -O "$ARCHIVE"
else
	echo "Tomcat archive already exists."
fi

# Validate archive
if ! tar -tzf "$ARCHIVE" >/dev/null 2>&1; then
	echo "ERROR: Invalid Tomcat archive."
	exit 1
fi

# Extract Tomcat
echo "Extracting Tomcat..."
tar -xzf "$ARCHIVE" -C /tmp

# Create Tomcat user if missing
if ! id tomcat &>/dev/null; then
	echo "Creating tomcat user..."
	useradd --system --home-dir "$INSTALL_DIR" \
		--shell /sbin/nologin tomcat
else
	echo "Tomcat user already exists."
fi

# Install Tomcat files
echo "Installing Tomcat..."
mkdir -p "$INSTALL_DIR"
cp -a "/tmp/apache-tomcat-${VERSION}/." "$INSTALL_DIR/"

# Set ownership
chown -R tomcat:tomcat "$INSTALL_DIR"

# Detect Java home
JAVA_PATH=$(readlink -f "$(command -v java)")
JAVA_HOME=$(dirname "$(dirname "$JAVA_PATH")")

echo "Detected JAVA_HOME: $JAVA_HOME"

# Create systemd service
echo "Creating Tomcat service..."

cat >/etc/systemd/system/tomcat.service <<EOF
[Unit]
Description=Apache Tomcat
After=network.target

[Service]
Type=simple
User=tomcat
Group=tomcat
WorkingDirectory=${INSTALL_DIR}
Environment="JAVA_HOME=${JAVA_HOME}"
Environment="CATALINA_HOME=${INSTALL_DIR}"
Environment="CATALINA_BASE=${INSTALL_DIR}"
ExecStart=${INSTALL_DIR}/bin/catalina.sh run
ExecStop=${INSTALL_DIR}/bin/shutdown.sh
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd
systemctl daemon-reload

# Enable and start Tomcat
systemctl enable --now tomcat

# Validate service
if systemctl is-active --quiet tomcat; then
	echo "SUCCESS: Tomcat installed and running."
	systemctl status tomcat --no-pager
else
	echo "ERROR: Tomcat failed to start."
	journalctl -u tomcat -n 30 --no-pager
	exit 1
fi
