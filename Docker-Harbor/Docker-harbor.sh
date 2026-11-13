#!/usr/bin/env bash
#
# Provision Harbor Container Registry on CentOS Stream 9.
#
# Run:
#   sudo ./provision-harbor.sh
#
# Optional overrides:
#   HARBOR_VERSION=2.15.5
#   HARBOR_HOSTNAME=harbor.lab.local
#   HARBOR_IP=192.168.56.18
#   HARBOR_DATA=/data
#   HARBOR_INSTALL_DIR=/opt/harbor
#   CA_DIR=/root/harbor-ca
#   CERT_DIR=/etc/harbor/certs
#   HTTPS_PORT=443
#
# The script is designed for a fresh or existing CentOS Stream 9 lab VM.
# It does not configure Windows hosts-file entries or import the CA on clients.

set -Eeuo pipefail
umask 077

HARBOR_VERSION="${HARBOR_VERSION:-2.15.5}"
HARBOR_HOSTNAME="${HARBOR_HOSTNAME:-harbor.lab.local}"
HARBOR_IP="${HARBOR_IP:-192.168.56.18}"
HARBOR_DATA="${HARBOR_DATA:-/data}"
HARBOR_INSTALL_DIR="${HARBOR_INSTALL_DIR:-/opt/harbor}"
CA_DIR="${CA_DIR:-/root/harbor-ca}"
CERT_DIR="${CERT_DIR:-/etc/harbor/certs}"
HTTPS_PORT="${HTTPS_PORT:-443}"

INSTALLER_DIR="${HARBOR_INSTALL_DIR}/harbor"
INSTALLER_ARCHIVE="${HARBOR_INSTALL_DIR}/harbor-online-installer-v${HARBOR_VERSION}.tgz"
CA_CERT="${CA_DIR}/ca.crt"
CA_KEY="${CA_DIR}/ca.key"
SERVER_KEY="${CERT_DIR}/${HARBOR_HOSTNAME}.key"
SERVER_CSR="${CERT_DIR}/${HARBOR_HOSTNAME}.csr"
SERVER_CERT="${CERT_DIR}/${HARBOR_HOSTNAME}.crt"
EXT_FILE="${CERT_DIR}/harbor.ext"

log() { printf '\\n[%s] %s\\n' "$(date '+%F %T')" "$*"; }
die() {
	echo "ERROR: $*" >&2
	exit 1
}
have() { command -v "$1" >/dev/null 2>&1; }

[[ "${EUID}" -eq 0 ]] || die "Run this script as root (for example: sudo $0)."
[[ -f /etc/centos-release ]] || die "This script targets CentOS Stream 9."
grep -q 'CentOS Stream release 9' /etc/centos-release || die "Detected OS is not CentOS Stream 9."

for cmd in curl openssl sed grep awk; do
	have "$cmd" || die "Required command not found: $cmd"
done

[[ "$HARBOR_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "Invalid HARBOR_VERSION: $HARBOR_VERSION"
[[ "$HTTPS_PORT" =~ ^[0-9]+$ ]] || die "HTTPS_PORT must be numeric."
((HTTPS_PORT >= 1 && HTTPS_PORT <= 65535)) || die "HTTPS_PORT must be between 1 and 65535."

if [[ -z "${HARBOR_ADMIN_PASSWORD:-}" ]]; then
	read -r -s -p "Set Harbor admin password: " HARBOR_ADMIN_PASSWORD
	echo
	read -r -s -p "Confirm Harbor admin password: " HARBOR_ADMIN_PASSWORD_CONFIRM
	echo
	[[ "$HARBOR_ADMIN_PASSWORD" == "$HARBOR_ADMIN_PASSWORD_CONFIRM" ]] || die "Passwords do not match."
	unset HARBOR_ADMIN_PASSWORD_CONFIRM
fi
[[ -n "$HARBOR_ADMIN_PASSWORD" ]] || die "Harbor admin password cannot be empty."

log "Installing prerequisites"
dnf install -y dnf-plugins-core curl tar openssl ca-certificates

log "Configuring the official Docker CE repository"
if ! dnf repolist --enabled | grep -q 'docker-ce-stable'; then
	dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
fi

log "Installing Docker Engine and Compose plugin"
dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker

docker version >/dev/null
docker compose version >/dev/null

log "Preparing directories"
install -d -m 0755 "$HARBOR_INSTALL_DIR" "$HARBOR_DATA"
install -d -m 0700 "$CA_DIR"
install -d -m 0755 "$CERT_DIR"

log "Creating a lab CA if one does not already exist"
if [[ ! -s "$CA_KEY" || ! -s "$CA_CERT" ]]; then
	if [[ -e "$CA_KEY" || -e "$CA_CERT" ]]; then
		die "Only one CA file exists. Review $CA_DIR and restore the matching key/certificate pair before continuing."
	fi

	openssl genrsa -out "$CA_KEY" 4096
	chmod 0600 "$CA_KEY"
	openssl req -x509 -new -nodes \
		-key "$CA_KEY" \
		-sha256 \
		-days 3650 \
		-out "$CA_CERT" \
		-subj "/C=EG/O=Lab Infrastructure/OU=Harbor Lab/CN=Lab Root CA"
	chmod 0644 "$CA_CERT"
else
	log "Existing CA key and certificate found; preserving them."
	chmod 0600 "$CA_KEY"
	chmod 0644 "$CA_CERT"
fi

log "Creating Harbor server certificate if one does not already exist"
if [[ ! -s "$SERVER_KEY" || ! -s "$SERVER_CERT" ]]; then
	if [[ -e "$SERVER_KEY" || -e "$SERVER_CERT" ]]; then
		die "Only one Harbor server key/certificate exists. Review $CERT_DIR before continuing."
	fi

	openssl genrsa -out "$SERVER_KEY" 4096
	chmod 0600 "$SERVER_KEY"

	openssl req -new \
		-key "$SERVER_KEY" \
		-out "$SERVER_CSR" \
		-subj "/C=EG/O=Lab Infrastructure/OU=Harbor Lab/CN=${HARBOR_HOSTNAME}"

	cat >"$EXT_FILE" <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage=digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectAltName=@alt_names

[alt_names]
DNS.1=${HARBOR_HOSTNAME}
IP.1=${HARBOR_IP}
EOF

	openssl x509 -req \
		-in "$SERVER_CSR" \
		-CA "$CA_CERT" \
		-CAkey "$CA_KEY" \
		-CAcreateserial \
		-out "$SERVER_CERT" \
		-days 365 \
		-sha256 \
		-extfile "$EXT_FILE"

	chmod 0644 "$SERVER_CERT"
	chmod 0644 "$SERVER_CSR" "$EXT_FILE"
else
	log "Existing Harbor server key and certificate found; preserving them."
	chmod 0600 "$SERVER_KEY"
	chmod 0644 "$SERVER_CERT"
fi

log "Validating server certificate and private key"
openssl verify -CAfile "$CA_CERT" "$SERVER_CERT"
openssl verify -CAfile "$CA_CERT" -verify_hostname "$HARBOR_HOSTNAME" "$SERVER_CERT"

KEY_PUB="$(openssl pkey -in "$SERVER_KEY" -pubout 2>/dev/null | openssl sha256)"
CERT_PUB="$(openssl x509 -in "$SERVER_CERT" -pubkey -noout | openssl sha256)"
[[ "$KEY_PUB" == "$CERT_PUB" ]] || die "Harbor certificate does not match its private key."

log "Downloading Harbor online installer v${HARBOR_VERSION}"
if [[ ! -s "$INSTALLER_ARCHIVE" ]]; then
	curl -fL --retry 3 \
		"https://github.com/goharbor/harbor/releases/download/v${HARBOR_VERSION}/harbor-online-installer-v${HARBOR_VERSION}.tgz" \
		-o "$INSTALLER_ARCHIVE"
else
	log "Installer archive already exists; reusing it."
fi

if [[ ! -d "$INSTALLER_DIR" ]]; then
	tar -xzf "$INSTALLER_ARCHIVE" -C "$HARBOR_INSTALL_DIR"
fi
[[ -f "${INSTALLER_DIR}/harbor.yml.tmpl" ]] || die "Harbor installer template not found at ${INSTALLER_DIR}/harbor.yml.tmpl."

log "Generating harbor.yml from the installer template"
export HARBOR_HOSTNAME HTTPS_PORT SERVER_CERT SERVER_KEY HARBOR_ADMIN_PASSWORD HARBOR_DATA
if [[ -e "${INSTALLER_DIR}/harbor.yml" ]]; then
	cp -a "${INSTALLER_DIR}/harbor.yml" "${INSTALLER_DIR}/harbor.yml.backup.$(date +%Y%m%d%H%M%S)"
fi
cp "${INSTALLER_DIR}/harbor.yml.tmpl" "${INSTALLER_DIR}/harbor.yml"

# Update the standard Harbor template without relying on fragile sed escaping
# (administrator passwords may contain punctuation such as &, |, or backslashes).
python3 - "${INSTALLER_DIR}/harbor.yml" <<'PYCONFIG'
import os
import re
import sys

path = sys.argv[1]
settings = {
    "hostname": os.environ["HARBOR_HOSTNAME"],
    "port": os.environ["HTTPS_PORT"],
    "certificate": os.environ["SERVER_CERT"],
    "private_key": os.environ["SERVER_KEY"],
    "harbor_admin_password": os.environ["HARBOR_ADMIN_PASSWORD"],
    "data_volume": os.environ["HARBOR_DATA"],
}
with open(path, encoding="utf-8") as f:
    lines = f.readlines()

found = set()
output = []
inside_https = False
for line in lines:
    if re.match(r"^\s*#?https:\s*$", line):
        output.append("https:\n")
        inside_https = True
        continue
    if inside_https and re.match(r"^\S", line) and not line.startswith("#"):
        inside_https = False

    key_match = re.match(r"^(\s*)(#\s*)?(hostname|harbor_admin_password|data_volume|port|certificate|private_key):.*$", line)
    if key_match:
        indent, comment, key = key_match.groups()
        if key in ("port", "certificate", "private_key"):
            # Only modify the HTTPS block's settings, not unrelated keys.
            if not inside_https and key not in found:
                output.append(line)
                continue
            indent = "  "
        elif key in ("hostname", "harbor_admin_password", "data_volume"):
            indent = ""
        output.append(f"{indent}{key}: {settings[key]}\n")
        found.add(key)
    else:
        output.append(line)

required = {"hostname", "harbor_admin_password", "data_volume", "port", "certificate", "private_key"}
missing = required - found
if missing:
    raise SystemExit("Missing expected Harbor template keys: " + ", ".join(sorted(missing)))
with open(path, "w", encoding="utf-8") as f:
    f.writelines(output)
PYCONFIG
chmod 0600 "${INSTALLER_DIR}/harbor.yml"
unset HARBOR_ADMIN_PASSWORD

log "Adding local hostname mapping if it is not already present"
if ! getent hosts "$HARBOR_HOSTNAME" | grep -q "$HARBOR_IP"; then
	if ! grep -qE "^[[:space:]]*${HARBOR_IP}[[:space:]].*${HARBOR_HOSTNAME}([[:space:]]|$)" /etc/hosts; then
		printf '%s %s\\n' "$HARBOR_IP" "$HARBOR_HOSTNAME" >>/etc/hosts
	fi
fi

log "Running Harbor prepare"
cd "$INSTALLER_DIR"
./prepare

log "Installing / starting Harbor"
./install.sh

log "Deployment commands"
cat <<EOF

Harbor installation command completed.

URL: https://${HARBOR_HOSTNAME}
Admin username: admin
Harbor configuration: ${INSTALLER_DIR}/harbor.yml
Harbor data: ${HARBOR_DATA}
CA certificate (copy this to trusted clients): ${CA_CERT}
CA private key (NEVER distribute): ${CA_KEY}
Server certificate: ${SERVER_CERT}

Next validation:
  cd ${INSTALLER_DIR} && docker compose ps
  ss -lntp | grep ':${HTTPS_PORT}'
  curl --cacert ${CA_CERT} https://${HARBOR_HOSTNAME}/
  openssl s_client -connect ${HARBOR_HOSTNAME}:${HTTPS_PORT} \\
    -servername ${HARBOR_HOSTNAME} -CAfile ${CA_CERT} \\
    -verify_return_error </dev/null

Add this mapping to the Windows hosts file if required:
  ${HARBOR_IP} ${HARBOR_HOSTNAME}

Import ${CA_CERT} into the Windows Local Computer Trusted Root store.
The script does not alter Windows settings or automatically trust the CA on remote clients.
EOF

log "Provisioning script finished"
