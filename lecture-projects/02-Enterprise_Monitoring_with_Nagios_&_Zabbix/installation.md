# Infrastructure Monitoring – Zabbix & Nagios

This section documents the installation and configuration of two infrastructure monitoring solutions: **Zabbix** and **Nagios Core** on CentOS Stream 9.

---

# 1. Zabbix

## 1.1 Installation Guide

Follow the official Zabbix installation instructions using the link below:

[Zabbix 7.4 – CentOS 9 – PostgreSQL – Nginx](https://www.zabbix.com/download?zabbix=7.4&os_distribution=centos&os_version=9&components=server_frontend_agent&db=pgsql&ws=nginx)

![Zabbix Installation Guide](image-1.png)

## 1.2 Install PostgreSQL

**Important:** Before initializing the Zabbix database (Step C in the official installation guide), make sure the required PostgreSQL version is installed and running.

Install PostgreSQL 16:

```bash
dnf module install postgresql:16/server
```

Initialize the database:

```bash
postgresql-setup --initdb
```

Enable and start PostgreSQL:

```bash
systemctl enable --now postgresql
```

## 1.3 PostgreSQL Authentication Troubleshooting

During the installation, I encountered an issue because I didn't know the password assigned to the PostgreSQL `zabbix` user.

### Step 1: Reset the Zabbix Database User Password

Switch to the PostgreSQL operating system account:

```bash
sudo -i -u postgres
```

Open the PostgreSQL command-line interface:

```sql
psql
```

Reset the password:

```sql
ALTER USER zabbix WITH PASSWORD 'zabbix';
```

Exit PostgreSQL:

```sql
\q
```

### Step 2: Test the Database Connection

Test the connection using the following command:

```bash
psql -h 127.0.0.1 -p 5432 -U zabbix -d zabbix -W
```

However, I received the following error:

```text
Password:

psql: error: connection to server at "127.0.0.1",
port 5432 failed: FATAL: Ident authentication failed
for user "zabbix"
```

### Step 3: Understand the Authentication Error

This error means that PostgreSQL is using **Ident authentication** for TCP connections instead of password-based authentication.

PostgreSQL is trying to authenticate the operating-system identity associated with the connection rather than validating the password entered by the user.

### Step 4: Locate the Active PostgreSQL Authentication File

Connect to PostgreSQL and execute:

```bash
psql -c "SHOW hba_file;"
```

Example output:

```text
                 hba_file
-----------------------------------------
 /var/lib/pgsql/data/pg_hba.conf
(1 row)
```

### Step 5: Inspect the Authentication Rules

Execute:

```bash
grep -nEv '^[[:space:]]*(#|$)' \
/var/lib/pgsql/data/pg_hba.conf
```

Example output:

```text
113:local   all             all                         peer
115:host    all             all     127.0.0.1/32        ident
117:host    all             all     ::1/128             ident
120:local   replication     all                         peer
121:host    replication     all     127.0.0.1/32        ident
122:host    replication     all     ::1/128             ident
```

The `ident` authentication method is responsible for the connection failure.

### Step 6: Change Authentication to SCRAM-SHA-256

Edit the PostgreSQL authentication configuration:

```bash
vim /var/lib/pgsql/data/pg_hba.conf
```

Add the following rule before any general rule matching the same connection:

```text
host    zabbix    zabbix    127.0.0.1/32    scram-sha-256
```

This rule tells PostgreSQL to authenticate connections from the `zabbix` user to the `zabbix` database using password-based SCRAM-SHA-256 authentication.

### Step 7: Reload PostgreSQL

Apply the configuration changes:

```bash
sudo systemctl reload postgresql
```

### Step 8: Test Database Authentication Again

Execute:

```bash
psql -h 127.0.0.1 -p 5432 -U zabbix -d zabbix -W
```

Expected output:

```text
Password:
psql (16.8)
Type "help" for help.

zabbix=> SELECT current_user, current_database();

 current_user | current_database
--------------+------------------
 zabbix       | zabbix
(1 row)

zabbix=>
```

<ins>Result:</ins> PostgreSQL password authentication is now working successfully.

## 1.4 Continue Zabbix Installation

After resolving the PostgreSQL authentication issue, continue following the remaining steps in the official Zabbix installation guide.

![Zabbix Installation Step](image-2.png)

![Zabbix Installation Step](image-3.png)

![Zabbix Installation Step](image-4.png)

![Zabbix Installation Step](image-5.png)

## 1.5 Zabbix Web Interface

After completing the installation, access the Zabbix web interface through your browser.

Default login credentials:

| Parameter | Value |
|---|---|
| Username | `Admin` |
| Password | `zabbix` |

![Zabbix Login](image-6.png)

**Security Note:** Change the default administrator password immediately after the first login.

---

# 2. Nagios

## 2.1 Introduction

Nagios is an infrastructure monitoring solution used to monitor servers, network devices, applications, and services.

Nagios monitoring consists of three main components:

| Component | Description |
|---|---|
| **Nagios Core** | The central monitoring engine responsible for scheduling checks, processing results, and generating alerts. |
| **Nagios Plugins** | Executable programs that perform actual monitoring checks and return results to Nagios Core. |
| **Nagios Cross-Platform Agent (NCPA)** | An agent that collects monitoring information from remote servers and exposes it through an API. |

## 2.2 Nagios Core

Nagios Core is the main monitoring application installed on the central monitoring server.

Its responsibilities include:

- Monitoring hosts and services.
- Scheduling monitoring checks.
- Processing check results.
- Detecting Warning and Critical states.
- Generating alerts and notifications.
- Providing the web interface.
- Managing monitoring configurations.

## 2.3 Nagios Plugins

Nagios Plugins are executable programs that perform specific monitoring operations and return their results to Nagios Core.

For example, when monitoring disk utilization, Nagios Core does not calculate disk usage itself. Instead, it executes a plugin called `check_disk`.

### Common Nagios Plugins

| Plugin | Function |
|---|---|
| `check_ping` | Checks network connectivity. |
| `check_http` | Checks HTTP/HTTPS availability. |
| `check_disk` | Monitors disk utilization. |
| `check_load` | Monitors Linux system load. |
| `check_users` | Monitors logged-in users. |
| `check_procs` | Monitors running processes. |
| `check_tcp` | Checks TCP port availability. |
| `check_snmp` | Monitors SNMP-enabled devices. |

## 2.4 Nagios Cross-Platform Agent (NCPA)

NCPA is a monitoring agent developed by Nagios Enterprises. It allows Nagios Core to collect monitoring information from remote operating systems.

### Supported Operating Systems

- Linux (CentOS, RHEL, Ubuntu, etc.).
- Windows Server.
- macOS.
- Other supported Unix-like platforms.

### Monitoring Capabilities

| Metric | What You Can Monitor |
|---|---|
| CPU | CPU utilization. |
| Memory | RAM utilization. |
| Disk | Disk usage and available space. |
| Network | Network interfaces and traffic. |
| Processes | Running processes. |
| Services | Operating system services. |
| System | OS information and uptime. |

### How Does NCPA Communicate with Nagios?

NCPA provides an API, normally accessible over HTTPS using TCP port `5693`.

Nagios Core communicates with the NCPA API to retrieve monitoring information from remote systems.

---

# 3. Nagios Core Installation on CentOS 9

## 3.1 Prepare the Operating System

### Disable SELinux

For this lab installation, disable SELinux:

```bash
sed -i 's/SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config
setenforce 0
```

> **Note:** Disabling SELinux is suitable for a temporary lab environment. In production, configure the required SELinux policies instead.

### Install Required Dependencies

```bash
dnf install -y gcc glibc glibc-common perl httpd php wget gd gd-devel s-nail postfix

dnf install -y openssl-devel
```

Update the operating system:

```bash
dnf update -y
```

## 3.2 Download Nagios Core

Navigate to the temporary directory:

```bash
cd /tmp
```

Download the latest Nagios Core release automatically from GitHub:

```bash
wget --output-document="nagioscore.tar.gz" \
$(wget -q -O - https://api.github.com/repos/NagiosEnterprises/nagioscore/releases/latest \
| grep '"browser_download_url":' \
| grep -o 'https://[^"]*')
```

Extract the downloaded archive:

```bash
tar xzf nagioscore.tar.gz
```

Navigate to the extracted directory:

```bash
cd /tmp/nagios-*/
```

## 3.3 Compile and Install Nagios Core

Configure the installation:

```bash
./configure
```

Compile the source code:

```bash
make all
```

Create the required Nagios groups and users:

```bash
make install-groups-users
```

Add Apache to the Nagios group:

```bash
usermod -a -G nagios apache
```

Install Nagios Core:

```bash
make install
```

Install the systemd service:

```bash
make install-daemoninit
```

Enable Apache:

```bash
systemctl enable httpd.service
```

Configure command permissions:

```bash
make install-commandmode
```

Install sample configuration files:

```bash
make install-config
```

Install the Apache web configuration:

```bash
make install-webconf
```

## 3.4 Configure Firewall

Allow HTTP traffic through the firewall:

```bash
firewall-cmd --zone=public --add-port=80/tcp
```

Make the firewall rule permanent:

```bash
firewall-cmd --zone=public --add-port=80/tcp --permanent
```

Reload firewall configuration:

```bash
firewall-cmd --reload
```

## 3.5 Create Nagios Web Authentication

Create the Nagios administrator account:

```bash
htpasswd -c /usr/local/nagios/etc/htpasswd.users nagiosadmin
```

Enter and confirm the password when prompted.

> **Note:** The `-c` option creates a new password file. Do not use it when adding additional users to an existing file, as it overwrites the file.

## 3.6 Start Nagios and Apache Services

Start Apache:

```bash
systemctl start httpd.service
```

Start Nagios:

```bash
systemctl start nagios.service
```

Verify both services:

```bash
systemctl status httpd.service
systemctl status nagios.service
```

## 3.7 Access Nagios Web Interface

Open your browser and navigate to the Nagios server IP address or FQDN.

Example:

```text
http://10.25.5.143/nagios
```

You will be prompted for authentication.

| Parameter | Value |
|---|---|
| Username | `nagiosadmin` |
| Password | The password created using `htpasswd` which is `Nagios`. |

---

# 4. Installing Nagios Plugins

Nagios Core requires plugins to execute monitoring checks.

Without Nagios Plugins, the monitoring engine cannot perform the standard checks required to monitor hosts and services.

## 4.1 Install Plugin Dependencies

```bash
dnf install -y gcc glibc glibc-common make gettext automake autoconf wget openssl-devel net-snmp net-snmp-utils epel-release
```

Enable the CRB repository:

```bash
dnf config-manager --set-enabled crb
```

Install the Perl SNMP module:

```bash
dnf install -y perl-Net-SNMP
```

## 4.2 Download Nagios Plugins

Navigate to the temporary directory:

```bash
cd /tmp
```

Download the latest Nagios Plugins release from GitHub:

```bash
wget --output-document="nagios-plugins.tar.gz" \
$(wget -q -O - https://api.github.com/repos/nagios-plugins/nagios-plugins/releases/latest \
| grep '"browser_download_url":' \
| grep -o 'https://[^"]*')
```

Extract the archive:

```bash
tar zxf nagios-plugins.tar.gz
```

Navigate to the extracted directory:

```bash
cd /tmp/nagios-plugins-*/
```

## 4.3 Compile and Install Nagios Plugins

Configure the installation:

```bash
./configure
```

Compile:

```bash
make
```

Install:

```bash
make install
```

## 4.4 Plugin Installation Location

After successful installation, the plugins will be located in:

```text
/usr/local/nagios/libexec/
```

You can verify the installed plugins:

```bash
ls -lh /usr/local/nagios/libexec/
```

---

# 5. Testing Nagios Plugins

After installing Nagios Plugins, access the Nagios web interface:

```text
http://10.25.5.143/nagios
```

Alternatively:

```text
http://core-013.domain.local/nagios
```

Navigate to a host or service object and select:

**Commands → Re-schedule the next check**

This forces Nagios to execute the monitoring check again.

If the plugins are installed correctly and the configuration is valid, the previous plugin-related error should disappear and the correct monitoring output should be displayed.

---

# 6. Nagios Service Management

Use the following commands to manage the Nagios service.

### Start Nagios

```bash
systemctl start nagios.service
```

### Stop Nagios

```bash
systemctl stop nagios.service
```

### Restart Nagios

```bash
systemctl restart nagios.service
```

### Check Nagios Service Status

```bash
systemctl status nagios.service
```

### Enable Nagios at System Startup

```bash
systemctl enable nagios.service
```

### Disable Nagios at System Startup

```bash
systemctl disable nagios.service
```

---

# 7. Useful References

| Resource | Link |
|---|---|
| Zabbix Official Documentation | [Zabbix Documentation](https://www.zabbix.com/documentation/current/en/manual) |
| Zabbix Download Page | [Zabbix Download](https://www.zabbix.com/download) |
| Nagios Core Documentation | [Nagios Documentation](https://www.nagios.org/documentation/) |
| Nagios Core GitHub | [Nagios Core Repository](https://github.com/NagiosEnterprises/nagioscore) |
| Nagios Plugins GitHub | [Nagios Plugins Repository](https://github.com/nagios-plugins/nagios-plugins) |
| NCPA Documentation | [NCPA Documentation](https://www.nagios.org/ncpa/) |

---

**Lab Status:** Zabbix and Nagios Core installation and initial configuration documented.