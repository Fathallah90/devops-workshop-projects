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

Download and install NCPA
First, update Ubuntu:

```bash
sudo apt update
sudo apt upgrade -y
sudo apt install -y wget curl
```
Recommended method: Install using the Nagios repository
I recommend this method because future updates can be managed through apt.

```bash
# Add Nagios repository
echo "deb https://repo.nagios.com/deb/$(lsb_release -cs) /" \
  | sudo tee /etc/apt/sources.list.d/nagios.list

# Install repository signing key
sudo apt install -y curl gnupg

curl -fsSL https://repo.nagios.com/GPG-KEY-NAGIOS-V3 \
  | sudo gpg --dearmor -o /usr/share/keyrings/nagios-archive-keyring.gpg
```
Configure the repository to use the key:

```bash
echo "deb [signed-by=/usr/share/keyrings/nagios-archive-keyring.gpg] https://repo.nagios.com/deb/$(lsb_release -cs) /" \
  | sudo tee /etc/apt/sources.list.d/nagios.list
```

Install NCPA:

```bash
sudo apt update
sudo apt install -y ncpa
```

Configure NCPA

```bash
sudo vim /usr/local/ncpa/etc/ncpa.cfg
```
Find the [api] section:

```bash
[api]
community_string = mytoken
```
Change the default token to a strong password, for example:

```bash
[api]
community_string = Nagios100@@100n
```

Start and enable NCPA

```bash
sudo systemctl list-units --type=service | grep ncpa
```

Restart the Service

```bash
sudo systemctl restart ncpa
sudo systemctl enable ncpa
sudo ss -lntp | grep 5693
```

You should see NCPA listening on TCP port 5693.

Test the NCPA API locally

`curl -k "https://127.0.0.1:5693/api?token=Nagios100@@100n"`

Access NCPA Web Interface

`https://UBUNTU_SERVER_IP:5693`


### Integrating Client to Nagios Core

Note: to integrate nagios core with hosts you need python script to install NCPA plugin on nagios core, nagios use this plugin to communicate with NCPA API.

let's install it

```bash
cd /tmp
wget https://assets.nagios.com/downloads/ncpa/check_ncpa.tar.gz
tar -xzf check_ncpa.tar.gz
```

Copy the plugin into the Nagios plugins directory:

```bash
sudo cp check_ncpa.py /usr/local/nagios/libexec/
sudo chown nagios:nagios /usr/local/nagios/libexec/check_ncpa.py
sudo chmod 755 /usr/local/nagios/libexec/check_ncpa.py
```

verify installation

`/usr/local/nagios/libexec/check_ncpa.py -V`

Configure the NCPA API token

on the host machine ( ubuntu web01)

`sudo vim /usr/local/ncpa/etc/ncpa.cfg`

Replace mytoken with your own secure token as we done before

Now test the NCPA plugin from nagios core server:

```bash
/usr/local/nagios/libexec/check_ncpa.py \
-H web01 \
-t 'Nagios100@@100n' \
-P 5693 \
-M system/agent_version
```

Expected output:

`OK: Agent_version was ['3.x.x']`

Step 4. Create the Nagios command definition
Nagios needs a command definition that tells it how to execute the NCPA plugin.

Open:
`sudo vim /usr/local/nagios/etc/objects/commands.cfg`

Add:

```bash

define command {
    command_name    check_ncpa
    command_line    $USER1$/check_ncpa.py -H $HOSTADDRESS$ $ARG1$ }
```

Step 5. Store the API token securely
Rather than writing your API token directly into the host configuration, store it as a Nagios resource macro.

Open:

`sudo vim /usr/local/nagios/etc/resource.cfg`

Add:

`$USER5$=Nagios100@@100n`

Restrict access:

```bash
sudo chown nagios:nagios /usr/local/nagios/etc/resource.cfg
sudo chmod 640 /usr/local/nagios/etc/resource.cfg
```

Step 6. Create the Ubuntu host configuration
Create a separate configuration file for web01:

`sudo vim /usr/local/nagios/etc/objects/web01.cfg`

```bash


###############################################################################
# Ubuntu 22.04 - web01
# Monitoring through Nagios Cross-Platform Agent (NCPA)
###############################################################################

define host {
    use                     linux-server
    host_name               web01
    alias                   Ubuntu 22.04 Web Server
    address                 192.168.56.15
    check_period            24x7
    check_interval          5
    retry_interval          1
    max_check_attempts      5
    notification_interval   30
    notification_period     24x7
}

###############################################################################
# NCPA Agent Version
###############################################################################

define service {
    use                     generic-service
    host_name               web01
    service_description     NCPA Agent Version
    check_command           check_ncpa!-t '$USER5$' -P 5693 -M system/agent_version
}

###############################################################################
# CPU Usage
###############################################################################

define service {
    use                     generic-service
    host_name               web01
    service_description     CPU Usage
    check_command           check_ncpa!-t '$USER5$' -P 5693 -M cpu/percent -q aggregate=avg -w 80 -c 90
}

###############################################################################
# Memory Usage
###############################################################################

define service {
    use                     generic-service
    host_name               web01
    service_description     Memory Usage
    check_command           check_ncpa!-t '$USER5$' -P 5693 -M memory/virtual/percent -w 80 -c 90
}

###############################################################################
# Disk Usage - Root Partition
###############################################################################

define service {
    use                     generic-service
    host_name               web01
    service_description     Root Disk Usage
    check_command           check_ncpa!-t '$USER5$' -P 5693 -M 'disk/logical/|/used_percent' -w 80 -c 90
}

###############################################################################
# Process Count
###############################################################################

define service {
    use                     generic-service
    host_name               web01
    service_description     Process Count
    check_command           check_ncpa!-t '$USER5$' -P 5693 -M processes -w 300 -c 400
}

###############################################################################
# System Uptime
###############################################################################

define service {
    use                     generic-service
    host_name               web01
    service_description     System Uptime
    check_command           check_ncpa!-t '$USER5$' -P 5693 -M system/uptime
}

```

Step 7. Register the configuration file
Nagios must know where your new host configuration file is located.

Open:

`sudo vim /usr/local/nagios/etc/nagios.cfg`

Add:

`cfg_file=/usr/local/nagios/etc/objects/web01.cfg`

Validate the Nagios configuration

```bash
sudo /usr/local/nagios/bin/nagios \
-v /usr/local/nagios/etc/nagios.cfg
```

Restart Nagios Core

Verify monitoring through Nagios Web UI

`http://nag01/nagios/`

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

**Verify Endpoint on Nagios Dashboard**

![alt text](../screenshots/nagios-01.png)