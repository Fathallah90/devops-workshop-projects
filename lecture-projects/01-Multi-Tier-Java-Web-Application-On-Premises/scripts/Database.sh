#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# MariaDB - Unattended Vagrant Provisioning
# Target: Rocky Linux / AlmaLinux / RHEL / CentOS Stream
# ============================================================

# Configuration
MARIADB_ROOT_PASSWORD="admin123"
MARIADB_DATABASE="appdb"
MARIADB_USER="appuser"
MARIADB_PASSWORD="appdb_123"
MARIADB_BIND_ADDRESS="0.0.0.0"

# VProfile application database
VPROFILE_DB_NAME="accounts"
VPROFILE_DB_USER="admin"
VPROFILE_DB_PASSWORD="admin123"

# Source code
VPROFILE_REPO_URL="https://github.com/hkhcoder/vprofile-project.git"
VPROFILE_BRANCH="main"
VPROFILE_DIR="/opt/vprofile-project"

log() {
	echo "[$(date '+%F %T')] $*"
}

die() {
	log "ERROR: $*"
	exit 1
}

# Require root privileges
[[ $EUID -eq 0 ]] || die "Run this script as root."

# Validate configuration
for variable in MARIADB_ROOT_PASSWORD MARIADB_PASSWORD; do
	value="${!variable}"
	[[ "$value" =~ ^[a-zA-Z0-9_@%+=.,:-]+$ ]] ||
		die "$variable contains unsupported characters."
done

[[ "$MARIADB_DATABASE" =~ ^[a-zA-Z0-9_]+$ ]] ||
	die "Invalid database name."

[[ "$MARIADB_USER" =~ ^[a-zA-Z0-9_]+$ ]] ||
	die "Invalid database username."

[[ "$MARIADB_BIND_ADDRESS" == "0.0.0.0" ||
	"$MARIADB_BIND_ADDRESS" == "127.0.0.1" ]] ||
	die "Invalid bind address."

# Check OS
source /etc/os-release
case "${ID:-}" in
rocky | almalinux | rhel | centos) ;;
*) die "Unsupported OS: ${ID:-unknown}" ;;
esac

# Install MariaDB
log "Installing MariaDB Server..."
dnf -y install mariadb-server

# Configure MariaDB network listening
log "Configuring MariaDB..."
install -d -m 0755 /etc/my.cnf.d

cat >/etc/my.cnf.d/99-vagrant.cnf <<EOF
[mysqld]
bind-address=${MARIADB_BIND_ADDRESS}
EOF

# Start service
log "Enabling and starting MariaDB..."
systemctl enable mariadb
systemctl start mariadb

# Temporary protected client configuration
TMP_CNF="$(mktemp)"
chmod 600 "$TMP_CNF"
trap 'rm -f "$TMP_CNF"' EXIT

write_client_config() {
	cat >"$TMP_CNF" <<EOF
[client]
user=root
password=${MARIADB_ROOT_PASSWORD}
protocol=socket
EOF
}

# Support both a fresh installation and reruns
if mariadb --protocol=socket -u root -e "SELECT 1" >/dev/null 2>&1; then
	ADMIN=(mariadb --protocol=socket -u root)
else
	write_client_config
	ADMIN=(mariadb --defaults-extra-file="$TMP_CNF")

	"${ADMIN[@]}" -e "SELECT 1" >/dev/null 2>&1 ||
		die "Unable to authenticate as MariaDB root."
fi

# Secure installation
log "Setting root password and securing MariaDB..."

"${ADMIN[@]}" <<SQL
ALTER USER 'root'@'localhost'
    IDENTIFIED BY '${MARIADB_ROOT_PASSWORD}';

CREATE USER IF NOT EXISTS 'root'@'%'
    IDENTIFIED BY '${MARIADB_ROOT_PASSWORD}';

ALTER USER 'root'@'%'
    IDENTIFIED BY '${MARIADB_ROOT_PASSWORD}';

GRANT ALL PRIVILEGES ON *.* TO 'root'@'%'
    WITH GRANT OPTION;

DELETE FROM mysql.user WHERE User = '';

DROP DATABASE IF EXISTS test;

DELETE FROM mysql.db
WHERE Db = 'test' OR Db LIKE 'test\\_%';

FLUSH PRIVILEGES;
SQL

write_client_config
ADMIN=(mariadb --defaults-extra-file="$TMP_CNF")

# Create application database and user
log "Creating application database and user..."

"${ADMIN[@]}" <<SQL
CREATE DATABASE IF NOT EXISTS \`${MARIADB_DATABASE}\`;

CREATE USER IF NOT EXISTS '${MARIADB_USER}'@'localhost'
    IDENTIFIED BY '${MARIADB_PASSWORD}';

ALTER USER '${MARIADB_USER}'@'localhost'
    IDENTIFIED BY '${MARIADB_PASSWORD}';

GRANT ALL PRIVILEGES ON \`${MARIADB_DATABASE}\`.*
    TO '${MARIADB_USER}'@'localhost';

CREATE DATABASE IF NOT EXISTS accounts;
GRANT ALL PRIVILEGES ON accounts.* TO '${MARIADB_USER}'@'localhost';
FLUSH PRIVILEGES;
SQL

# Restart and verify
log "Restarting MariaDB..."
systemctl restart mariadb
systemctl is-active --quiet mariadb ||
	die "MariaDB failed to start."

log "Verifying configuration..."
"${ADMIN[@]}" -e "
SELECT VERSION() AS mariadb_version;
SELECT User, Host FROM mysql.user WHERE User IN ('root', '');
SHOW DATABASES LIKE 'test';
"

# ============================================================
# VProfile database and source-code provisioning
# ============================================================

# Install Git only if missing.
if ! command -v git >/dev/null 2>&1; then
	log "Installing Git..."
	dnf -y install git
fi

# Create the VProfile database if it does not exist.
VPROFILE_DB_EXISTS="$("${ADMIN[@]}" -Nse \
	"SELECT COUNT(*) FROM information_schema.SCHEMATA
    WHERE SCHEMA_NAME='${VPROFILE_DB_NAME}'")"

if [[ "$VPROFILE_DB_EXISTS" -eq 0 ]]; then
	log "Creating database ${VPROFILE_DB_NAME}..."
	"${ADMIN[@]}" -e \
		"CREATE DATABASE \`${VPROFILE_DB_NAME}\`"
else
	log "Database ${VPROFILE_DB_NAME} already exists; preserving it."
fi

# Create the remote VProfile database user if missing.
VPROFILE_USER_EXISTS="$("${ADMIN[@]}" -Nse \
	"SELECT COUNT(*) FROM mysql.user
    WHERE User='${VPROFILE_DB_USER}' AND Host='%'")"

if [[ "$VPROFILE_USER_EXISTS" -eq 0 ]]; then
	log "Creating ${VPROFILE_DB_USER}@%..."
	"${ADMIN[@]}" <<SQL
CREATE USER '${VPROFILE_DB_USER}'@'%'
    IDENTIFIED BY '${VPROFILE_DB_PASSWORD}';
SQL
else
	log "Database user ${VPROFILE_DB_USER}@% already exists; preserving its password."
fi

# Ensure the VProfile user has privileges on the accounts database.
"${ADMIN[@]}" -e \
	"GRANT ALL PRIVILEGES ON \`${VPROFILE_DB_NAME}\`.*
    TO '${VPROFILE_DB_USER}'@'%'"

# Download source code only if the directory does not exist.
if [[ ! -d "${VPROFILE_DIR}/.git" ]]; then
	if [[ -e "$VPROFILE_DIR" ]]; then
		die "$VPROFILE_DIR exists but is not a Git repository; preserving it."
	fi

	log "Cloning VProfile source code..."
	git clone --branch "$VPROFILE_BRANCH" --single-branch \
		"$VPROFILE_REPO_URL" "$VPROFILE_DIR"
else
	log "VProfile Git repository already exists; preserving local changes."
fi

# Verify that the SQL dump exists.
VPROFILE_SQL="${VPROFILE_DIR}/src/main/resources/db_backup.sql"

[[ -f "$VPROFILE_SQL" ]] ||
	die "Database dump not found: $VPROFILE_SQL"

# Import only when the database has no base tables.
VPROFILE_TABLE_COUNT="$("${ADMIN[@]}" -Nse \
	"SELECT COUNT(*) FROM information_schema.tables
    WHERE table_schema='${VPROFILE_DB_NAME}'
    AND table_type='BASE TABLE'")"

if [[ "$VPROFILE_TABLE_COUNT" -eq 0 ]]; then
	log "Importing VProfile database dump..."

	VPROFILE_CNF="$(mktemp)"
	chmod 600 "$VPROFILE_CNF"

	cat >"$VPROFILE_CNF" <<EOF
[client]
user=${VPROFILE_DB_USER}
password=${VPROFILE_DB_PASSWORD}
protocol=socket
EOF

	if ! mariadb --defaults-extra-file="$VPROFILE_CNF" \
		"$VPROFILE_DB_NAME" <"$VPROFILE_SQL"; then
		rm -f "$VPROFILE_CNF"
		die "VProfile database import failed."
	fi

	rm -f "$VPROFILE_CNF"
	log "VProfile database import completed."
else
	log "Database ${VPROFILE_DB_NAME} already contains tables; skipping import."
fi

# Verify the resulting database.
"${ADMIN[@]}" -e "
SHOW TABLES FROM \`${VPROFILE_DB_NAME}\`;
SHOW GRANTS FOR '${VPROFILE_DB_USER}'@'%';
"

log "VProfile database provisioning completed."
log "MariaDB provisioning completed successfully."
