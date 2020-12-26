# K8s on Ubuntu on KVM

This Vagrant config makes master and worker VMs. The VMs are Ubuntu 18.04 (or 20.04). Concepts and considerations are written at <https://pgillich.medium.com/setup-on-premise-kubernetes-with-kubeadm-metallb-traefik-and-vagrant-8a9d8d28951a>.

> It's forked from <https://github.com/coolsvap/kubeadm-vagrant>.

The default provider is VirtualBox, but Libvirt/KVM can also be used on Ununtu. VirtualBox provider tested on Windows 10 with Cygwin (MobaXterm), too.

Used versions:

* Host: Ubuntu 18.04.5 or Windows 10
* Guests: peru/ubuntu-18.04-server-amd64 20201203.01
* Kubernetes: latest (v1.20.1)
* Flannel: latest (v0.13.1-rc1)
* containerd.io: 1.2.13-2
* docker-ce: 5:19.03.11~3-0
* docker-ce-cli: 5:19.03.11~3-0
* Helm: 3 latest (v3.4.2)
* Metrics: 0.3.6 (Heml 2.11.4)
* Kubernetes Dashboard: latest (v2.1.0)
* MetalLB: latest (v0.9.5)
* Traefik: 1 latest (1.7.19, Helm 1.81.0)

Traefik version is same to K3s built-in Traefik version, because Traefik 2 does not support the whole functionality on Ingress (for example: path prefix strip), moreover there is no newer than 1.7.19 image in Docker Hub.

**For homeworkers**: if you are using VPN, a few K8s subnets (10.244.0.0/16, 10.96.0.0/12, 192.168.26.0/24) may not be in the VPN-routed address space. See more details in the `Vagrantfile` and at <https://coreos.com/flannel/docs/latest/kubernetes.html> and <https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-init/>.

> Warning: This example is not secure and must be hardened before using it in production.

## Preparations

### Install KVM and virt-manager

Follow <https://help.ubuntu.com/community/KVM/Installation>

Tested version: 1:2.11+dfsg-1ubuntu7.34

### Install Vagrant

Follow <https://www.vagrantup.com/docs/installation>

Tested version: 2.2.14

### Preparing VirtualBox

Preparing VirtualBox on Windows 10 or Ubuntu host:

```sh
export VAGRANT_DEFAULT_PROVIDER=virtualbox
```

Preparing VirtualBox on Windows 10 host:

```sh
vagrant plugin install vagrant-hostmanager
```

### Install KVM support for Vagrant

Based on:

* <https://github.com/vagrant-libvirt/vagrant-libvirt>
* <https://ostechnix.com/how-to-use-vagrant-with-libvirt-kvm-provider/>

Preparing KVM/Libvirt on Ubuntu host:

```sh
sudo apt install qemu libvirt-daemon-system libvirt-clients libxslt-dev libxml2-dev libvirt-dev zlib1g-dev ruby-dev ruby-libvirt ebtables dnsmasq-base
#MAYBE: sudo apt install libvirt-bin vagrant-libvirt

export VAGRANT_DEFAULT_PROVIDER=libvirt
vagrant plugin install vagrant-libvirt
vagrant plugin install vagrant-mutate
#MAYBE: vagrant plugin uninstall vagrant-disksize
```

### Download box image

Selecting guest image:

```sh
BOX_IMAGE="peru/ubuntu-18.04-server-amd64"
# Using Ubuntu 20.04 in VMs, instead of 18.04 (Vagrantfile must be updated, too):
#BOX_IMAGE="peru/ubuntu-20.04-server-amd64"
```

Download box image:

```sh
vagrant box add --provider ${VAGRANT_DEFAULT_PROVIDER} ${BOX_IMAGE}
```

### Install kubectl

<https://kubernetes.io/docs/tasks/tools/install-kubectl/>

On Ubuntu:

```sh
sudo apt-get update && sudo apt-get install -y apt-transport-https gnupg2 curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubectl
```

Tested version: v1.20.1

## Configuration

Optional: if you have instaled kubeadm somewhere, generate below token, which will be set as `KUBETOKEN` in `Vagrantfile`:

```sh
kubeadm token generate
```

Review Vagrant config at the beginning of `Vagrantfile`...

Open hosts file:

```sh
sudo nano /etc/hosts
# On Windows: C:\Windows\System32\drivers\etc\hosts
```

Add external Traefik IP address - FQDN pair (see `NODE_IP_NW` and `OAM_DOMAIN` in `Vagrantfile`) and save+exit:

```text
192.168.26.254       oam.cluster-01.company.com
```

## Deployment

Install:

```sh
#MAYBE: export VAGRANT_DEFAULT_PROVIDER=libvirt
vagrant up --no-parallel
```

Kubectl config for host (warning: it overwrites `~/.kube/config`):

On Ubuntu:

```sh
vagrant ssh master -c 'cat .kube/config' >~/.kube/config
chmod go-rw ${HOME}/.kube/config
```

Note: in MobaXterm the vagrant ssh works only in `cmd` shell.

Test commands:

```sh
kubectl cluster-info
kubectl get nodes -o wide
kubectl get all -A -o wide
kubectl get endpoints -A
kubectl get ingress -A
sudo crictl ps -a
kubectl top pod --containers -A
```

## Usage

### Dashboards

Getting token to Kubernetes Dashboard:

```sh
kubectl -n kubernetes-dashboard describe secret admin-user-token | grep ^token
```

Dashboards can be accessed trough ingress at:

* Traefik: <http://oam.cluster-01.company.com/dashboard/>
* Kubernetes: <https://oam.cluster-01.company.com/kubernetes/>

Dashboards can be accessed trough `kubectl proxy` (it should be run in a separated terminal) at:

* Traefik: <http://localhost:8001/api/v1/namespaces/kube-system/services/http:traefik-dashboard:80/proxy/dashboard/>
* Kubernetes: <http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/http:kubernetes-dashboard:/proxy/>
