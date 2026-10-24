# Prerequisite
1. Oracle VM Virtualbox
2. Vagrant

# Installation
Make sure that the vagrant host manager plugin is isntalled usig nthe below command.

`vagrant plugin install vagrant-hostmanager`

## Prepare VMs
### Prepare the Vagrantfile
Check it in the Project Folder

### Prepare VMs using Vagrant
1. go the to the path which contain the vagrantfile
2. in my case i will up only any vm to udate its packages and then use this vm to create vagrant box and reuse it, to avoid update & upgrade step each time in VMs
#### Steps

**Start VM and Login**

```bash
vagrant up db01 >> wait till the vm is being up
vagrant ssh db01
```
**Update Packages**

```bash
#!/bin/bash

sudo yum makecache
sudo yum update
```
**Clean VM**
```bash
#!/bin/bash

sudo yum clean all
sudo rm -rf /var/cache/yum
sudo rm -rf /tmp/*
sudo rm -rf /var/tmp/*
sudo journalctl --vacuum-time=1s
```
**Reset Machine ID**

```bash
#!/bin/bash

sudo truncate -s 0 /etc/machine-id
sudo rm -f /var/lib/dbus/machine-id
sudo ln -s /etc/machine-id /var/lib/dbus/machine-id
```
**Disable Firewall**
```bash
#!/bin/bash

sudo systemctl disable firewalld
```
**Install Base Tools**
```bash
#!/bin/bash

sudo yum install -y curl wget vim net-tools git epel-release
```
**Install VirtualBOX Guest Tools**
```bash
#!/bin/bash

sudo yum install -y kernel-devel kernel-headers elfutils-libelf-devel gcc make perl
```
**Install Latest Guest Addition Tools**

Mount Guest Addition Tools from Virtual Box VM

```bash
sudo mkdir -p /mnt/vboxga
sudo mount /dev/sr0 /mnt/vboxga
sudo sh /mnt/vboxga/VBoxLinuxAdditions.run
sudo modprobe vboxsf
sudo /sbin/rcvboxadd status
sudo /sbin/rcvboxadd status-kernel
sudo modinfo vboxsf
sudo reboot
```

**Install Insecure vagrant Public SSH Key**
```bash
#!/bin/bsh
sudo curl -fsSL \
  https://raw.githubusercontent.com/hashicorp/vagrant/main/keys/vagrant.pub \
  -o /home/vagrant/.ssh/authorized_keys

sudo chown vagrant:vagrant /home/vagrant/.ssh/authorized_keys
sudo chmod 600 /home/vagrant/.ssh/authorized_keys
```
**Create Vagrant Box from Existing VM**

Detect the vm name using vboxmanage

```cmd
VboxManage list vms

Vagrant package --base "MariaDB" --output "CentOS_9"
```
**Add Vagrant Box to Box List**

`vagrant box add + “box_file_path” + --name + “desired_box_name_on_vagrant_List”`

`vagrant box add "CentOS_9" --name "Golden_CentOS"`

### DB Initialization
We will Initialize DB Installation and Configuration using Shell Script

### Memcached Initialization


> [!NOTE]
> Bringing up all the vm’s may take a long time based on various factors, If vm setup stops in the middle run “vagrant up” command again.

> [!NOTE]
> All the vm’s hostname and /etc/hosts file entries will be automatically updated.