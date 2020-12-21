# K8s on Ubuntu on KVM

This Vagrant config makes master and worker VMs. The VMs are Ubuntu 18.04.

The default provider was VirtualBox, but this description uses KVM. If you would like to use VirtualBox hypervisor, please read original Vagrantfile at <https://github.com/coolsvap/kubeadm-vagrant/blob/master/Ubuntu/Vagrantfile>.

Used versions:

* Host: Ubuntu 18.04.5
* Guests: peru/ubuntu-18.04-server-amd64 20201203.01
* Kubernetes: latest (v1.20.1)
* Flannel: latest (v0.13.1-rc1)
* containerd.io: 1.2.13-2
* docker-ce: 5:19.03.11~3-0
* docker-ce-cli: 5:19.03.11~3-0
* Helm: 3 latest (v3.4.2)
* Kubernetes Dashboard: latest (v2.1.0)
* MetalLB: latest (v0.9.5)
* Traefik: 1 latest (1.7.19, Helm 1.81.0)

Traefik version is similar to K3s built-in Traefik version, because Traefik 2 does not support the whole functionality on Ingress (for example: path prefix strip), moreover there is no newer than 1.7.19 image in Docker Hub.

Traefik (ingress controller) and MetalLB (L2/ARP load balancer) setup are based on:

* <https://medium.com/google-cloud/kubernetes-nodeport-vs-loadbalancer-vs-ingress-when-should-i-use-what-922f010849e0>
* <https://www.devtech101.com/2019/02/23/using-metallb-and-traefik-load-balancing-for-your-bare-metal-kubernetes-cluster-part-1/>
* <https://www.devtech101.com/2019/03/02/using-traefik-as-your-ingress-controller-combined-with-metallb-on-your-bare-metal-kubernetes-cluster-part-2/>
* <https://stackoverflow.com/questions/50585616/kubernetes-metallb-traefik-how-to-get-real-client-ip>
* <https://www.disasterproject.com/kubernetes-with-external-dns/>
* <https://metallb.universe.tf/installation/>

## Preparations

### Install KVM and virt-manager

Follow <https://help.ubuntu.com/community/KVM/Installation>

Tested version: 1:2.11+dfsg-1ubuntu7.34

### Install Vagrant

Follow <https://www.vagrantup.com/docs/installation>

Tested version: 2.2.14

### Install KVM support for Vagrant

Based on:

* <https://github.com/vagrant-libvirt/vagrant-libvirt>
* <https://ostechnix.com/how-to-use-vagrant-with-libvirt-kvm-provider/>

```sh
sudo apt install qemu libvirt-daemon-system libvirt-clients libxslt-dev libxml2-dev libvirt-dev zlib1g-dev ruby-dev ruby-libvirt ebtables dnsmasq-base
#maybe: sudo apt install libvirt-bin vagrant-libvirt
export VAGRANT_DEFAULT_PROVIDER=libvirt
vagrant plugin install vagrant-libvirt
vagrant plugin install vagrant-mutate
#maybe: vagrant plugin uninstall vagrant-disksize
vagrant box add --provider libvirt "peru/ubuntu-18.04-server-amd64"
```

### Install kubectl

<https://kubernetes.io/docs/tasks/tools/install-kubectl/>

```sh
sudo apt-get update && sudo apt-get install -y apt-transport-https gnupg2 curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubectl
```

Tested version: v1.20.1

### Generate security info

Change below generated strings in `Vagrantfile`

KUBETOKEN (if you have instaled kubeadm somewhere):

```sh
kubeadm token generate
```

TRAEFIK_PWD (without `admin:` prefix):

```sh
htpasswd -nbm admin <NEW_PASSWORD>
```

The current Traefik dashboard password to admin user is: admin

## Setup

Install:

```sh
#maybe: export VAGRANT_DEFAULT_PROVIDER=libvirt
vagrant up --no-parallel
#vagrant up master
#vagrant up node1
#vagrant up node2
```

Kubectl config for host:

```sh
vagrant ssh master -c 'cat .kube/config' >~/.kube/config
chmod go-rw ${HOME}/.kube/config
```

Accessing Dashboard at <http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/http:kubernetes-dashboard:/proxy/>

```sh
kubectl -n kubernetes-dashboard describe secret admin-user-token | grep ^token
kubectl proxy
```

## Web server deployment

Generate deployment file:

```sh
kubectl run nginx-example --image=nginx --port=80 --expose=true --dry-run -o yaml > nginx-example.yaml
```

Set `nginx.yaml:Service.spec.type=LoadBalancer`:

nginx.yaml

```yaml
kind: Service
spec:
  type: LoadBalancer
```

Deploy:

```sh
kubectl apply -f nginx-example.yaml
```
