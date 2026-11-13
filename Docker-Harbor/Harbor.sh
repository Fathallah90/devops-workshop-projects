#!/bin/bash
#------------

dnf update -y
sudo dnf install -y curl wget tar vim openssl firewalld chrony bind-utils iproute

sudo hostnamectl set-hostname harbor.lab.local

sudo dnf -y install dnf-plugins-core

sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker

cd /opt/harbor || exit
wget https://github.com/goharbor/harbor/releases/download/v2.15.5/harbor-online-installer-v2.15.5.tgz

tar xzvf harbor-online-installer-v2.15.5.tgz
cd /opt/harbor/harbor || exit

### Configure HTTPS Access
#---------------------------

## Generate a self-signed certificate
# ---------------------------
mkdir -p /root/harbor-ca
mkdir -p /etc/harbor/certs
chmod 700 /root/harbor-ca
chmod 700 /etc/harbor/certs

cd /root/harbor-ca || exit
openssl genrsa -out ca.key 4096
chmod 600 ca.key
