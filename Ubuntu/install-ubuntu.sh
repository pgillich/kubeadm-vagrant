#!/bin/sh

# Source: 
# http://kubernetes.io/docs/getting-started-guides/kubeadm/
# https://kubernetes.io/docs/setup/production-environment/container-runtimes/#docker

export DEBIAN_FRONTEND=noninteractive

sudo swapoff -a

sudo apt-get update
sudo apt-get install -y apt-transport-https gnupg2 curl ca-certificates software-properties-common

curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

sudo add-apt-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main"
sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

sudo apt-get update && sudo apt-get install -y \
  containerd.io=1.2.13-2 \
  docker-ce=5:19.03.11~3-0~ubuntu-$(lsb_release -cs) \
  docker-ce-cli=5:19.03.11~3-0~ubuntu-$(lsb_release -cs)

cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

sudo mkdir -p /etc/systemd/system/docker.service.d

sudo systemctl daemon-reload
sudo systemctl enable docker
sudo systemctl restart docker

sudo usermod -aG docker $USER

sudo apt-get install -y kubelet kubeadm kubectl kubernetes-cni
sudo systemctl enable kubelet && sudo systemctl start kubelet

sudo docker info | grep overlay
sudo docker info | grep systemd
