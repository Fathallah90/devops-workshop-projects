# Prerequisites

1. [Oracle VM VirtualBox](https://www.virtualbox.org/)
2. [Vagrant](https://developer.hashicorp.com/vagrant)

# Installation and Setup

## 1. Install the Vagrant Host Manager Plugin

Make sure the Vagrant Host Manager plugin is installed before starting the VMs.

```bash
vagrant plugin install vagrant-hostmanager
```

## 2. Prepare the VMs

### 2.1. Review the Vagrantfile

Check the `Vagrantfile` in the project folder. It defines the VMs, their configuration, networking, and provisioning scripts.

### 2.2. Start a VM

Navigate to the directory containing the `Vagrantfile`.

In this project, I prepare one VM first, update its packages, and create a reusable Vagrant box. This avoids repeating the package update and base configuration steps every time a VM is created.

Start the database VM and connect to it:

```bash
vagrant up db01
vagrant ssh db01
```

### 2.3. Update Packages

Run the following commands inside the VM:

```bash
sudo yum makecache
sudo yum update -y
```

### 2.4. Install Base Tools

Install the common utilities required for administration and troubleshooting:

```bash
sudo yum install -y curl wget vim net-tools git epel-release
```

### 2.5. Install VirtualBox Guest Additions Dependencies

Install the required build tools and kernel development packages:

```bash
sudo yum install -y kernel-devel kernel-headers \
  elfutils-libelf-devel gcc make perl
```

**Note:** The installed kernel development packages should match the running kernel. If necessary, update the kernel and reboot before installing Guest Additions.

### 2.6. Install VirtualBox Guest Additions

Mount the Guest Additions ISO from the VirtualBox VM menu, then run:

```bash
sudo mkdir -p /mnt/vboxga
sudo mount /dev/sr0 /mnt/vboxga
sudo sh /mnt/vboxga/VBoxLinuxAdditions.run
```

Verify the installation:

```bash
sudo modprobe vboxsf
sudo /sbin/rcvboxadd status
sudo /sbin/rcvboxadd status-kernel
sudo modinfo vboxsf
```

Reboot the VM:

```bash
sudo reboot
```

### 2.7. Clean the VM

Remove cached packages and temporary files before packaging the VM:

```bash
sudo yum clean all
sudo rm -rf /var/cache/yum/*
sudo rm -rf /tmp/*
sudo rm -rf /var/tmp/*
sudo journalctl --vacuum-time=1s
```

### 2.8. Reset the Machine ID

Reset the machine ID so cloned VMs can generate their own unique identities:

```bash
sudo truncate -s 0 /etc/machine-id
sudo rm -f /var/lib/dbus/machine-id
sudo ln -s /etc/machine-id /var/lib/dbus/machine-id
```

### 2.9. Configure the Firewall

If your lab environment requires the firewall to be disabled, run:

```bash
sudo systemctl disable --now firewalld
```

**Security note:** Disabling the firewall is suitable only for an isolated lab where this is intentional. Prefer configuring the required firewall rules when possible.

### 2.10. Configure the Vagrant SSH Public Key

Vagrant boxes commonly use an SSH public key for the `vagrant` account. The following command installs HashiCorp's publicly available Vagrant insecure key:

```bash
sudo install -d -o vagrant -g vagrant -m 700 /home/vagrant/.ssh

sudo curl -fsSL \
  https://raw.githubusercontent.com/hashicorp/vagrant/main/keys/vagrant.pub \
  -o /home/vagrant/.ssh/authorized_keys

sudo chown vagrant:vagrant /home/vagrant/.ssh/authorized_keys
sudo chmod 600 /home/vagrant/.ssh/authorized_keys
```

> [!WARNING]
> The default Vagrant public key is publicly known and is not secure for production use. Use it only in an isolated development or lab environment.

## 3. Create a Reusable Vagrant Box

After preparing the VM, shut it down from inside the guest or from the host:

```bash
sudo poweroff
```

### 3.1. Identify the VirtualBox VM

Run the following commands on the host machine:

```cmd
VBoxManage list vms
```

Find the exact VM name you want to package.

### 3.2. Package the VM

Use the VM name shown by `VBoxManage list vms`:

```cmd
vagrant package --base "MariaDB" --output "CentOS_9.box"
```

Replace `MariaDB` with your actual VirtualBox VM name if it differs.

### 3.3. Add the Box to Vagrant

Register the generated box with Vagrant:

```bash
vagrant box add "CentOS_9.box" --name "Golden_CentOS"
```

Verify that it was added:

```bash
vagrant box list
```

You can now reference `Golden_CentOS` in your `Vagrantfile`.

## 4. Initialize Application Components

Each component has its own installation and configuration script. Review the script, then configure it as a provisioner in the `Vagrantfile`.

### 4.1. Database Initialization

Use [Database.sh](../scripts/Database.sh) to install and configure the database.

### 4.2. RabbitMQ Initialization

Use [RabbitMQ.sh](../scripts/RabbitMQ.sh) to install and configure RabbitMQ.

### 4.3. Memcached Initialization

Use [Memcached.sh](../scripts/Memcached.sh) to install and configure Memcached.

### 4.4. Tomcat Initialization

Use [Tomcat.sh](../scripts/Tomcat.sh) to install and configure Apache Tomcat.

### 4.5. Maven Initialization

Use [Maven.sh](../scripts/Maven.sh) to install Maven and prepare the application build environment.

### 4.6. Nginx Initialization

Use [Nginx.sh](../scripts/Nginx.sh) to install and configure Nginx as the web server or reverse proxy.

## 5. Start and Provision the VMs

After reviewing the `Vagrantfile` and the provisioning scripts, start the required VMs:

```bash
vagrant up
```

To start a specific VM:

```bash
vagrant up db01
```

If provisioning fails, review the error output and rerun the appropriate command after correcting the issue.

> [!NOTE]
> Starting all VMs may take some time, depending on your host resources, network connectivity, and package repositories. If the process stops partway through, review the error and run `vagrant up` again.

> [!NOTE]
> The Vagrant Host Manager plugin automatically manages VM hostnames and `/etc/hosts` entries according to your `Vagrantfile` configuration.

