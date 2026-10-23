# Prerequisite
1. Oracle VM Virtualbox
2. Vagrant

# Installation
Make sure that the vagrant host manager plugin is isntalled usig nthe below command.

`vagrant plugin install vagrant-hostmanager`

# Prepare the Vagrantfile
Check it in the Project Folder

# Prepare VMs using Vagrant
1. go the to the path which contain the vagrantfile
2. Create the VMs using the below Command
`vagrant up`


> [!NOTE]
> Bringing up all the vm’s may take a long time based on various factors, If vm setup stops in the middle run “vagrant up” command again.

> [!INFO]
> All the vm’s hostname and /etc/hosts file entries will be automatically updated.

