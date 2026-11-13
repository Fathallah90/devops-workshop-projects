# Harbor Private Container Registry on CentOS Stream 9

A step-by-step lab guide for deploying **Harbor v2.15.5** with HTTPS on a CentOS Stream 9 virtual machine. This document starts with the VM and network prerequisites, then covers Docker Engine, TLS certificates, Harbor configuration, installation, client trust, and end-to-end push/pull validation.

> **Lab scope:** This is a learning and testing deployment. The CA private key is stored on the Harbor VM for convenience. For production, use an independently managed CA, protect private keys, size the VM and storage appropriately, and implement backups, monitoring, access controls, and a tested recovery procedure.

---

## 1. Lab overview

Harbor is an open-source container registry that stores, signs, scans, and distributes container images. It provides a web interface and registry API, user/project management, role-based access control, and image management features.

### 1.1 Lab architecture

| Component | Value |
|---|---|
| Operating system | CentOS Stream 9 x86_64 |
| VM platform | Oracle VirtualBox |
| Hostname | `harbor.lab.local` |
| Host-only IP | `192.168.56.18/24` |
| NAT interface | `enp0s3` |
| Host-only interface | `enp0s8` |
| Harbor version | `2.15.5` |
| Harbor FQDN | `harbor.lab.local` |
| HTTPS endpoint | `https://harbor.lab.local:443` |
| Harbor data directory | `/data` |
| Harbor installation directory | `/opt/harbor/harbor` |
| TLS certificate directory | `/etc/harbor/certs` |
| Lab CA directory | `/root/harbor-ca` |
| Registry administrator | `admin` |

The VM uses two network interfaces:

- **NAT (`enp0s3`)**: outbound internet connectivity for package and container image downloads.
- **Host-only (`enp0s8`)**: private connectivity between the Windows host and the Harbor VM.

The Windows host and any other lab client must resolve `harbor.lab.local` to `192.168.56.18`.

### 1.2 Network flow

```text
Windows host / Docker client
        |
        | HTTPS TCP/443
        | harbor.lab.local -> 192.168.56.18
        v
CentOS Stream 9 VM
        |
        +-- Docker Engine
        |
        +-- Harbor services (Docker Compose)
        |     +-- Nginx (HTTPS endpoint)
        |     +-- Harbor Core
        |     +-- Registry
        |     +-- Registry Controller
        |     +-- Portal
        |     +-- Database
        |     +-- Redis
        |     +-- Job Service
        |     +-- Log
        |
        +-- /data (Harbor persistent data)
```

### 1.3 Resource notes

The lab VM used approximately 2 vCPUs and 3.6 GiB of visible RAM. This is a constrained testing configuration, not a production sizing recommendation. Harbor runs several containers; low memory can cause slow startup, container restarts, or poor performance. The VM also needs sufficient free disk space for images, layers, logs, and metadata.

---

## 2. Prepare the CentOS Stream 9 virtual machine

### 2.1 Create the VM

Create a CentOS Stream 9 x86_64 VM in VirtualBox.

Suggested lab settings:

- 2 vCPUs or more.
- 4 GB RAM or more if available.
- 60–80 GB virtual disk or larger depending on image storage.
- Network Adapter 1: **NAT**.
- Network Adapter 2: **Host-only Adapter**.

Install CentOS Stream 9 and ensure you can log in with an account that has `sudo` privileges.

### 2.2 Identify the network interfaces

Run:

```bash
ip -br address
ip route
```

The lab configuration should resemble:

```text
enp0s3   UP   10.0.2.15/24
enp0s8   UP   192.168.56.18/24
```

The NAT address may differ. The host-only address should be the address you choose for the registry.

Confirm internet access:

```bash
ping -c 3 1.1.1.1
getent hosts download.docker.com
```

If the VM cannot reach the internet, fix the NAT adapter and DNS before continuing.

### 2.3 Set the hostname

```bash
sudo hostnamectl set-hostname harbor.lab.local
hostnamectl
```

Configure local name resolution on the Harbor VM:

```bash
echo '192.168.56.18 harbor.lab.local' | sudo tee -a /etc/hosts
getent hosts harbor.lab.local
```

If the entry already exists, edit `/etc/hosts` instead of adding duplicate lines.

### 2.4 Update the operating system

```bash
sudo dnf -y update
sudo dnf -y install curl wget tar gzip openssl ca-certificates \
  policycoreutils-python-utils firewalld
```

Enable the firewall service if you intend to manage host firewall rules with firewalld:

```bash
sudo systemctl enable --now firewalld
sudo systemctl status firewalld
```

Check SELinux:

```bash
getenforce
```

The lab environment used permissive mode. Do not treat disabling SELinux as a general Harbor requirement. For a production deployment, keep SELinux enforcing and validate the required policy and file contexts.

---

## 3. Configure Docker Engine and Docker Compose

Harbor is deployed using Docker Engine and Docker Compose.

### 3.1 Add the Docker CE repository

```bash
sudo dnf -y install dnf-plugins-core
sudo dnf config-manager --add-repo \
  https://download.docker.com/linux/centos/docker-ce.repo
```

Confirm that the repository is available:

```bash
sudo dnf repolist
```

### 3.2 Install Docker Engine and plugins

```bash
sudo dnf -y install docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin
```

Start and enable Docker:

```bash
sudo systemctl enable --now docker
sudo systemctl status docker
```

Check the installed versions:

```bash
docker --version
docker compose version
docker buildx version
```

The lab deployment used Docker Engine `29.9.3` and Docker Compose plugin `v5.7.1`. Versions can differ depending on when the repository is used.

### 3.3 Validate Docker

```bash
sudo docker run --rm hello-world
```

This test confirms that Docker can download and run a container image.

> Run Docker commands with `sudo` unless you deliberately configure a non-root user for Docker access. Membership in the `docker` group grants root-equivalent privileges.

---

## 4. Configure hostname resolution on the Windows host

The Windows host must resolve the registry name to the Harbor VM's host-only IP.

Open **Notepad as Administrator**, then open:

```text
C:\Windows\System32\drivers\etc\hosts
```

Add:

```text
192.168.56.18 harbor.lab.local
```

Save the file. In an elevated PowerShell window, run:

```powershell
ipconfig /flushdns
Resolve-DnsName harbor.lab.local
```

The returned address should be `192.168.56.18`.

If `Resolve-DnsName` does not show the hosts-file entry on your Windows version, test with:

```powershell
ping harbor.lab.local
```

The important point is that the hostname resolves to the host-only address, not the VM's NAT address.

---

## 5. Create the lab Certificate Authority (CA)

Harbor will expose HTTPS using a server certificate signed by a private lab CA. This avoids using an untrusted self-signed server certificate directly.

### 5.1 Understand the certificate files

| File | Purpose | Secret? |
|---|---|---|
| `ca.key` | Private key of the lab CA; signs server certificates | **Yes** |
| `ca.crt` | Public CA certificate; installed as a trusted root on clients | No |
| `harbor.lab.local.key` | Harbor HTTPS server private key | **Yes** |
| `harbor.lab.local.csr` | Certificate signing request | No |
| `harbor.lab.local.crt` | Harbor HTTPS server certificate | No |
| `harbor.ext` | X.509 certificate extensions, including SANs | No |

### 5.2 Create protected directories

Run on the Harbor VM:

```bash
sudo install -d -m 700 /root/harbor-ca
sudo install -d -m 755 /etc/harbor/certs
```

### 5.3 Generate the CA private key

```bash
sudo openssl genrsa \
  -out /root/harbor-ca/ca.key 4096

sudo chmod 600 /root/harbor-ca/ca.key
```

The CA private key is highly sensitive. Do not copy it to Windows clients or Docker clients.

### 5.4 Generate the CA certificate

```bash
sudo openssl req -x509 -new -nodes \
  -key /root/harbor-ca/ca.key \
  -sha256 -days 3650 \
  -out /root/harbor-ca/ca.crt \
  -subj "/C=EG/O=Lab Infrastructure/OU=Harbor Lab/CN=Lab Root CA"

sudo chmod 644 /root/harbor-ca/ca.crt
```

Inspect the CA certificate:

```bash
openssl x509 -in /root/harbor-ca/ca.crt \
  -noout -subject -issuer -dates
```

### 5.5 Generate the Harbor server private key

```bash
sudo openssl genrsa \
  -out /etc/harbor/certs/harbor.lab.local.key 4096

sudo chmod 600 /etc/harbor/certs/harbor.lab.local.key
```

### 5.6 Generate a certificate signing request (CSR)

```bash
sudo openssl req -sha256 -new \
  -key /etc/harbor/certs/harbor.lab.local.key \
  -out /etc/harbor/certs/harbor.lab.local.csr \
  -subj "/C=EG/O=Lab Infrastructure/OU=Harbor Lab/CN=harbor.lab.local"
```

### 5.7 Add Subject Alternative Names (SAN)

Modern clients validate the Subject Alternative Name (SAN). The certificate must contain the exact DNS name used by clients. The lab certificate also includes the host-only IP.

Create the extensions file:

```bash
sudo tee /etc/harbor/certs/harbor.ext > /dev/null <<'EOF'
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage=digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectAltName=@alt_names

[alt_names]
DNS.1=harbor.lab.local
IP.1=192.168.56.18
EOF
```

If you change the registry hostname or IP, update the SAN entries and issue a new certificate.

### 5.8 Sign the Harbor server certificate

```bash
sudo openssl x509 -req \
  -in /etc/harbor/certs/harbor.lab.local.csr \
  -CA /root/harbor-ca/ca.crt \
  -CAkey /root/harbor-ca/ca.key \
  -CAcreateserial \
  -out /etc/harbor/certs/harbor.lab.local.crt \
  -days 365 -sha256 \
  -extfile /etc/harbor/certs/harbor.ext

sudo chmod 644 /etc/harbor/certs/harbor.lab.local.crt
sudo chmod 600 /etc/harbor/certs/harbor.lab.local.key
```

### 5.9 Validate the certificate and hostname

Verify the certificate chain:

```bash
sudo openssl verify \
  -CAfile /root/harbor-ca/ca.crt \
  /etc/harbor/certs/harbor.lab.local.crt
```

Expected:

```text
/etc/harbor/certs/harbor.lab.local.crt: OK
```

Verify the hostname:

```bash
sudo openssl verify \
  -CAfile /root/harbor-ca/ca.crt \
  -verify_hostname harbor.lab.local \
  /etc/harbor/certs/harbor.lab.local.crt
```

Inspect SAN and validity:

```bash
openssl x509 \
  -in /etc/harbor/certs/harbor.lab.local.crt \
  -noout -subject -issuer -dates -ext subjectAltName
```

Optionally confirm the private key matches the certificate:

```bash
openssl x509 -in /etc/harbor/certs/harbor.lab.local.crt \
  -pubkey -noout | openssl pkey -pubin -outform DER | sha256sum

openssl pkey -in /etc/harbor/certs/harbor.lab.local.key \
  -pubout -outform DER | sha256sum
```

The two SHA-256 hashes must be identical.

---

## 6. Download and prepare Harbor

### 6.1 Download the Harbor online installer

The lab used Harbor `v2.15.5` and the online installer. The online installer downloads the required Harbor container images during installation.

```bash
sudo mkdir -p /opt/harbor
cd /opt/harbor

sudo curl -fL \
  -o harbor-online-installer-v2.15.5.tgz \
  https://github.com/goharbor/harbor/releases/download/v2.15.5/harbor-online-installer-v2.15.5.tgz
```

Check the downloaded archive:

```bash
ls -lh /opt/harbor/harbor-online-installer-v2.15.5.tgz
tar -tzf /opt/harbor/harbor-online-installer-v2.15.5.tgz | head
```

For production, verify release checksums/signatures against the official release information before installation.

### 6.2 Extract the installer

```bash
cd /opt/harbor
sudo tar -xzf harbor-online-installer-v2.15.5.tgz
cd /opt/harbor/harbor
```

The installer directory contains scripts and the Harbor configuration template.

### 6.3 Back up and edit `harbor.yml`

```bash
sudo cp harbor.yml harbor.yml.original
sudo vi harbor.yml
```

Set the key configuration values:

```yaml
hostname: harbor.lab.local

https:
  port: 443
  certificate: /etc/harbor/certs/harbor.lab.local.crt
  private_key: /etc/harbor/certs/harbor.lab.local.key

harbor_admin_password: CHANGE_THIS_TO_A_STRONG_PASSWORD

data_volume: /data
```

Important configuration notes:

- `hostname`: the DNS name clients use to reach Harbor. Do not include `https://` or a path.
- `https.port`: the external HTTPS port. This lab uses TCP/443.
- `https.certificate`: absolute path to the Harbor server certificate.
- `https.private_key`: absolute path to the matching private key.
- `harbor_admin_password`: initial password for the built-in `admin` account. Replace the placeholder with a strong unique password. Do not commit the real password to Git.
- `data_volume`: persistent storage location for Harbor data.

The HTTP listener is not enabled in this lab configuration. Keep the HTTP configuration commented/disabled when using HTTPS-only access.

Review the relevant settings:

```bash
grep -nE '^(hostname:|https:|  port:|  certificate:|  private_key:|harbor_admin_password:|data_volume:)' harbor.yml
```

Do not publish `harbor.yml` if it contains a real administrator password.

### 6.4 Check required files and directories

```bash
sudo test -r /etc/harbor/certs/harbor.lab.local.crt
sudo test -r /etc/harbor/certs/harbor.lab.local.key
sudo mkdir -p /data
sudo ls -ld /data /etc/harbor/certs
```

---

## 7. Run Harbor preparation and installation

### 7.1 Run the prepare script

From the Harbor installer directory:

```bash
cd /opt/harbor/harbor
sudo ./prepare
```

This reads `harbor.yml` and generates the configuration files used by Harbor's Docker Compose deployment.

The prepare output may include messages about optional CA files for external storage or Redis not being present. These are relevant when configuring those external services with custom CA trust. They do not automatically mean the Harbor HTTPS server certificate is invalid. Review the full output and stop if `prepare` reports a fatal configuration or certificate error.

### 7.2 Run the installer

For a standard installation:

```bash
sudo ./install.sh
```

The online installer pulls the required Harbor images, creates the Harbor Docker network, and starts the service containers.

Wait for the installer to finish. A successful deployment reports that Harbor has been installed and started successfully.

### 7.3 Inspect the running containers

```bash
cd /opt/harbor/harbor
sudo docker compose ps
```

The deployment should include Harbor services such as:

- `harbor-log`
- `registry`
- `registryctl`
- `harbor-core`
- `harbor-portal`
- `harbor-db`
- `redis`
- `harbor-jobservice`
- `nginx`

Container names and the exact presentation can vary by release/configuration. Check that services are running and investigate any container in an exited or restarting state.

Check Docker logs for a service:

```bash
sudo docker compose logs --tail=100 harbor-core
sudo docker compose logs --tail=100 nginx
sudo docker compose logs --tail=100 registry
```

---

## 8. Configure firewall access

Harbor's external HTTPS endpoint uses TCP/443 in this lab.

If firewalld is active, allow HTTPS:

```bash
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
sudo firewall-cmd --list-services
```

If you prefer to limit access to the host-only lab network, use a suitable firewalld zone/rich rule for your environment rather than exposing the service to every network. Also ensure the VirtualBox host-only network is configured as intended.

Confirm the listener:

```bash
sudo ss -lntp | grep ':443'
```

---

## 9. Test HTTPS from the Harbor VM

### 9.1 Test the HTTPS endpoint using the lab CA

```bash
curl --cacert /root/harbor-ca/ca.crt \
  https://harbor.lab.local/
```

A successful response may be HTML from the Harbor portal. The important result is that TLS verification succeeds and the endpoint responds.

### 9.2 Inspect the TLS handshake

```bash
openssl s_client \
  -connect 127.0.0.1:443 \
  -servername harbor.lab.local \
  -CAfile /root/harbor-ca/ca.crt \
  -verify_return_error </dev/null
```

Look for:

```text
Verify return code: 0 (ok)
```

If the hostname does not resolve, check `/etc/hosts` and DNS:

```bash
getent hosts harbor.lab.local
```

### 9.3 Check service health

```bash
sudo docker compose ps
sudo ss -lntp | grep ':443'
sudo curl --cacert /root/harbor-ca/ca.crt -I \
  https://harbor.lab.local/
```

---

## 10. Trust the private CA on Windows

A browser or Docker client will reject the Harbor certificate until it trusts the CA that issued it.

Only transfer the **public CA certificate** (`ca.crt`) to Windows. Never transfer `ca.key`.

### 10.1 Copy the CA certificate to Windows

From Windows PowerShell, if SSH access to the Harbor VM is enabled:

```powershell
scp root@192.168.56.18:/root/harbor-ca/ca.crt .
```

If root SSH login is disabled, copy the public certificate using an approved non-root account or a VirtualBox shared folder. Alternatively, stage a copy in a readable location on the VM:

```bash
sudo install -m 644 /root/harbor-ca/ca.crt /tmp/harbor-lab-ca.crt
```

Then retrieve `/tmp/harbor-lab-ca.crt` using your normal file-transfer method.

### 10.2 Import the CA into the Windows Local Machine trust store

Open PowerShell **as Administrator** in the directory containing `ca.crt`:

```powershell
Import-Certificate `
  -FilePath ".\ca.crt" `
  -CertStoreLocation "Cert:\LocalMachine\Root"
```

Confirm it is present:

```powershell
Get-ChildItem Cert:\LocalMachine\Root |
  Where-Object { $_.Subject -like "*Lab Root CA*" } |
  Format-List Subject, Issuer, NotAfter, Thumbprint
```

Close and reopen the browser, then visit:

```text
https://harbor.lab.local
```

The browser should show a valid HTTPS connection if name resolution and certificate trust are both correct.

> Importing the CA into Windows does not automatically configure every separate Docker daemon. A Docker Engine running inside another Linux VM, WSL distribution, or remote host needs the CA installed in that environment's trust configuration too.

---

## 11. Log in to Harbor and create a project

### 11.1 Sign in to the web portal

Open:

```text
https://harbor.lab.local
```

Use:

- Username: `admin`
- Password: the value configured as `harbor_admin_password` in `harbor.yml`

Change the administrator password after the initial login if required by your lab procedure.

### 11.2 Create a project

In the Harbor portal:

1. Open **Projects**.
2. Select **New Project**.
3. Enter a project name, for example `lab`.
4. Choose the visibility appropriate for the test. A private project requires authentication to pull images.
5. Create the project.

A Harbor image reference uses this pattern:

```text
harbor.lab.local/<project>/<repository>:<tag>
```

Example:

```text
harbor.lab.local/lab/nginx:1.27
```

---

## 12. Test Docker login, tag, push, and pull

Run these commands on a Docker client that can reach `harbor.lab.local` and trusts the lab CA.

### 12.1 Install CA trust on a Linux Docker client

For a Linux Docker Engine client, create a registry-specific CA directory:

```bash
sudo mkdir -p /etc/docker/certs.d/harbor.lab.local
sudo cp ca.crt /etc/docker/certs.d/harbor.lab.local/ca.crt
sudo systemctl restart docker
```

If the registry uses a non-default port, the directory name must include the port, for example `harbor.lab.local:8443`. This lab uses port 443, so the directory is `harbor.lab.local`.

On a CentOS/RHEL client, you may also install the CA into the operating-system trust store:

```bash
sudo cp ca.crt /etc/pki/ca-trust/source/anchors/harbor-lab-ca.crt
sudo update-ca-trust
```

Restart Docker after updating the registry-specific CA trust.

### 12.2 Log in

```bash
docker login harbor.lab.local
```

Enter `admin` or another Harbor user with permission to push to the project.

Do not put passwords directly on the command line or in scripts. Use an interactive login or a secure credential helper.

### 12.3 Pull a test image

```bash
docker pull nginx:latest
```

### 12.4 Tag the image for Harbor

```bash
docker tag nginx:latest harbor.lab.local/lab/nginx:latest
```

### 12.5 Push the image

```bash
docker push harbor.lab.local/lab/nginx:latest
```

### 12.6 Pull the image from Harbor

To validate that the registry can serve the pushed image:

```bash
docker image rm harbor.lab.local/lab/nginx:latest
docker pull harbor.lab.local/lab/nginx:latest
```

Confirm the image exists:

```bash
docker images | grep harbor.lab.local
```

The repository and tag should also appear in the Harbor project in the web portal.

---

## 13. Common administration commands

Run from `/opt/harbor/harbor`.

### Check status

```bash
sudo docker compose ps
```

### Follow all service logs

```bash
sudo docker compose logs -f
```

### Follow one service

```bash
sudo docker compose logs -f harbor-core
```

### Stop Harbor

```bash
sudo docker compose down
```

This stops and removes the Compose containers and network. Persistent data under `/data` is retained.

### Start Harbor

```bash
sudo docker compose up -d
```

### Restart Harbor

```bash
sudo docker compose restart
```

### Reconfigure after changing `harbor.yml`

Back up the configuration, edit it, then regenerate and apply the configuration:

```bash
cd /opt/harbor/harbor
sudo cp harbor.yml harbor.yml.backup.$(date +%F-%H%M%S)
sudo vi harbor.yml
sudo ./prepare
sudo docker compose down
sudo docker compose up -d
```

If you change the certificate paths, hostname, or other deployment-critical settings, verify the generated configuration and follow the upgrade/reconfiguration guidance for the exact Harbor release. Do not run an installer or upgrade procedure blindly against an existing data directory.

---

## 14. Troubleshooting

### 14.1 Browser reports certificate not trusted

Check:

- Windows trusts `ca.crt` in the Local Machine Trusted Root Certification Authorities store.
- The certificate was signed by the expected CA.
- The client is connecting to `harbor.lab.local`, not an unrelated IP/name.
- The server certificate SAN includes `DNS:harbor.lab.local`.
- The browser was restarted after importing the CA.

Useful server-side command:

```bash
openssl verify -CAfile /root/harbor-ca/ca.crt \
  -verify_hostname harbor.lab.local \
  /etc/harbor/certs/harbor.lab.local.crt
```

### 14.2 `curl` reports name resolution failure

```bash
getent hosts harbor.lab.local
cat /etc/hosts
```

Ensure the Harbor VM has the local `/etc/hosts` entry and Windows has the Windows hosts-file entry.

### 14.3 Connection refused on port 443

```bash
sudo docker compose ps
sudo ss -lntp | grep ':443'
sudo docker compose logs --tail=100 nginx
sudo firewall-cmd --list-all
```

Confirm the Harbor containers are running, Nginx is listening, and the firewall permits TCP/443.

### 14.4 Docker reports `x509: certificate signed by unknown authority`

The Docker daemon does not trust the lab CA. Install `ca.crt` in the Docker daemon's trust configuration on the machine running the daemon, then restart Docker.

Do not disable TLS verification or configure the registry as insecure as a workaround for a CA trust problem.

### 14.5 Harbor container is restarting or exited

```bash
sudo docker compose ps
sudo docker compose logs --tail=200 <service-name>
sudo df -h
sudo free -h
```

Check the failing service logs, free disk space, and available memory.

### 14.6 Certificate expired or hostname changed

Inspect validity and SAN:

```bash
openssl x509 -in /etc/harbor/certs/harbor.lab.local.crt \
  -noout -dates -ext subjectAltName
```

Issue a replacement certificate with the correct SAN, update the certificate/key files, rerun the appropriate Harbor configuration preparation, and restart/redeploy the affected services according to the Harbor release documentation.

---

## 15. Backup and security considerations

At minimum, protect and back up:

- Harbor persistent data under `/data`.
- Harbor configuration (`harbor.yml`) with secrets protected.
- The CA certificate (`ca.crt`) and the CA private key (`ca.key`) in a secure, separate backup location.
- Harbor server certificate and private key.
- Any external database, storage, or object-store configuration if introduced later.

A filesystem copy of `/data` while Harbor is actively writing may not be a consistent application backup. Use Harbor's documented backup/recovery approach or stop services and take a coordinated backup. Test restoration.

Security recommendations:

1. Keep the CA private key offline or on a dedicated CA system in production.
2. Do not commit private keys, passwords, or unencrypted secrets to Git.
3. Use unique strong passwords and named Harbor users instead of sharing `admin`.
4. Use project-level roles and least privilege.
5. Restrict TCP/443 to trusted networks where possible.
6. Keep Harbor, Docker Engine, and the host OS patched.
7. Monitor certificate expiry and storage consumption.
8. Configure image vulnerability scanning and signing policies where appropriate.
9. Back up Harbor data and validate restores.

---

## 16. Deployment checklist

Use this checklist to verify the lab from beginning to end:

- [ ] CentOS Stream 9 VM installed and updated.
- [ ] NAT interface provides internet access.
- [ ] Host-only interface has `192.168.56.18`.
- [ ] Hostname is `harbor.lab.local`.
- [ ] Harbor hostname resolves on the VM and Windows host.
- [ ] Docker Engine and Docker Compose plugin installed.
- [ ] Lab CA generated and protected.
- [ ] Harbor server certificate includes the correct DNS SAN and IP SAN.
- [ ] Certificate chain and hostname verification succeed.
- [ ] Harbor `harbor.yml` configured with HTTPS and `/data`.
- [ ] `./prepare` completes successfully.
- [ ] `./install.sh` completes successfully.
- [ ] Harbor containers are running.
- [ ] TCP/443 is listening and reachable.
- [ ] Windows trusts the lab CA.
- [ ] Harbor portal opens without a certificate warning.
- [ ] `admin` login succeeds.
- [ ] A project is created.
- [ ] Docker login succeeds.
- [ ] Test image push succeeds.
- [ ] Test image pull from Harbor succeeds.

---

## 17. References

- Harbor documentation: https://goharbor.io/docs/
- Harbor HTTPS configuration: https://goharbor.io/docs/2.16.0/install-config/configure-https/
- Harbor releases: https://github.com/goharbor/harbor/releases
- Docker Engine installation on CentOS: https://docs.docker.com/engine/install/centos/

> Documentation URLs and installation procedures can change. For future upgrades, use the documentation matching the exact Harbor release you deploy.
