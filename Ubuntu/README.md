# K8s on Ubuntu on KVM

This Vagrant config makes master and worker VMs. The VMs are Ubuntu 18.04 (or 20.04).
Concepts and considerations are written at <https://pgillich.medium.com/setup-on-premise-kubernetes-with-kubeadm-metallb-traefik-and-vagrant-8a9d8d28951a>.

> It's forked from <https://github.com/coolsvap/kubeadm-vagrant>.

The default provider is VirtualBox, but Libvirt/KVM can also be used on Ununtu. VirtualBox provider tested on Windows 10 with Cygwin (MobaXterm), too. There are several issues and manual workarounds with Windows host setup. The most robust setup is Ubuntu host + KVM provider.

The weird VM-in-VM also works: Windows 10 host --> VirtualBox or Hyper-V --> Ubuntu 18.04/20.04 middle --> KVM --> Ubuntu 18.04/20.04 guests. In this case, nested virtualization must be enabled on the host hypervisor. It's enabled in VirtualBox by default, but disabled in Hyper-V. To enable nested virtualization, see below:

* <https://docs.microsoft.com/en-us/system-center/vmm/vm-nested-virtualization?view=sc-vmm-20190>
* <https://docs.microsoft.com/en-us/virtualization/hyper-v-on-windows/user-guide/nested-virtualization>
* <https://github.com/MicrosoftDocs/Virtualization-Documentation/tree/master/hyperv-tools/Nested>

Used versions:

* Host: Ubuntu 18.04.5 (or 20.04.1) or Windows 10
* Guests: peru/ubuntu-18.04-server-amd64 20201203.01 (or 20.04). *Please check known issue **KVM BIOS cannot boot***
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

### Install Vagrant

Follow <https://www.vagrantup.com/docs/installation>

Tested version: 2.2.14

If you would like to avoid vagrant-libvirt compile issues, you can use my Docker image (see: `build_vagrant-libvirt.sh`), which contains Vagrant and all needed packages. Setup (should be added to `~/.bashrc`):

```sh
alias vagrant='
  mkdir -p ~/.vagrant.d/{boxes,data,tmp}; \
  docker run -it --rm \
    -e LIBVIRT_DEFAULT_URI \
    -v /var/run/libvirt/:/var/run/libvirt/ \
    -v ~/.vagrant.d:/.vagrant.d \
    -v $(pwd):$(pwd) \
    -w $(pwd) \
    --network host \
    pgillich/vagrant-libvirt:latest \
    vagrant'
```

So, you can skip:

* Vagrant install
* vagrant plugin install ...
* export VAGRANT_DEFAULT_PROVIDER=libvirt

### Install KVM and virt-manager

*Only if Libvirt/KVM provider is selected:*

Follow <https://help.ubuntu.com/community/KVM/Installation>

Tested version: 1:2.11+dfsg-1ubuntu7.34

### Install KVM support for Vagrant

*Only if Libvirt/KVM provider is selected:*

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

### Preparing VirtualBox

*Only if VirtualBox provider is selected:*

Preparing VirtualBox on Windows 10 or Ubuntu host:

```sh
export VAGRANT_DEFAULT_PROVIDER=virtualbox
```

### Preparing Vagrant

```sh
vagrant plugin install vagrant-hostmanager
```

The `export VAGRANT_DEFAULT_PROVIDER=...` can be added to `~/.bashrc`

### Download box image

Selecting guest image.

If Ubuntu 18.04 was selected:

```sh
BOX_IMAGE="peru/ubuntu-18.04-server-amd64"
```

If Ubuntu 20.04 (Vagrantfile must be updated, too) was selected:

```sh
BOX_IMAGE="peru/ubuntu-20.04-server-amd64"
```

Download box image:

```sh
vagrant box add --provider ${VAGRANT_DEFAULT_PROVIDER} ${BOX_IMAGE}
```

### Install kubectl

Based on: <https://kubernetes.io/docs/tasks/tools/install-kubectl/>

On Ubuntu host:

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

Review Vagrant config at the beginning of `Vagrantfile`. The `kubeadm` config file is equivalent to:<br/>
`sudo kubeadm init --apiserver-advertise-address=#{MASTER_IP} --pod-network-cidr=#{POD_NW_CIDR} --token #{KUBETOKEN} --token-ttl 0`
, plus `feature-gates=EphemeralContainers=true`

Helpful commands to check the `kubeadm` configuration:

```sh
sudo kubeadm config print init-defaults --component-configs KubeProxyConfiguration,KubeletConfiguration
sudo kubeadm config view
kubectl get cm -n kube-system kubeadm-config -o yaml
kubectl get cm -n kube-system kube-proxy -o yaml
vagrant ssh master -- 'sudo grep -r EphemeralContainers /etc/kubernetes/manifests/ /var/lib/kubelet/'
```

Open hosts file (On Windows: `C:\Windows\System32\drivers\etc\hosts`):

```sh
sudo nano /etc/hosts
```

Add external Traefik IP address - FQDN pair (see `NODE_IP_NW` and `OAM_DOMAIN` in `Vagrantfile`) and save+exit:

```text
192.168.26.254       oam.cluster-01.company.com
```

## Deployment

## Vagrant deployment

```sh
#export VAGRANT_DEFAULT_PROVIDER=...
vagrant up --no-parallel
```

### Kubectl config for host

*Warning: it overwrites `~/.kube/config`.*

```sh
mkdir -p ~/.kube
vagrant ssh master -- 'cat .kube/config' >~/.kube/config
chmod go-rw ${HOME}/.kube/config
```

Note: in MobaXterm, the `vagrant ssh` works only in `cmd` shell, see **Known issues** below.

### Test

```sh
kubectl cluster-info
kubectl get nodes -o wide
kubectl get all -A -o wide
kubectl get endpoints -A
kubectl get ingress -A
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

### Capturing network traffic on the node

The script `capture_pod.sh` starts `tcpdump` on the node and pipes captured packets to Wireshark. Wireshark may have additional privileges, see: <https://askubuntu.com/questions/74059/how-do-i-run-wireshark-with-root-privileges>

Export SSH client config:

```sh
vagrant ssh-config | grep -v 'Starting with UID' > ssh-config
```

Run capture script with Namespace and Pod name, for example (container name is optional):

```sh
./capture_pod.sh default my-nginx-596d59c679-9t4vp nginx
```

### Capturing network traffic in the container

The script `capture_in_pod.sh` builds a statically-compiled tcpdump, copies it into the container, starts the capture and pipes the packets to wireshark. Example usage (container name is optional):

```sh
./capture_in_pod.sh default my-nginx-596d59c679-9t4vp nginx
```

## Known Issues

### `vagrant ssh` in MobaXterm

It's failed. Use Windows `ssh` for example:

```sh
cmd /C vagrant ssh master
```

or:

```sh
PATH=$(cygpath "$WINDIR/System32/OpenSSH"):$PATH vagrant ssh master
```

Status: Workaround.

### Vagrant - VirtualBox - Flannel

A few services cannot be accessed on VirtualBox setup. It's not appeared with KVM provider (unique addresses were configured).

Vagrant typically assigns two interfaces to all VMs. The first, for which all hosts are assigned the IP address 10.0.2.15, is for external traffic that gets NATed.

See more details:

* <https://coreos.com/flannel/docs/latest/troubleshooting.html#vagrant>
* <https://discuss.kubernetes.io/t/flannel-yaml-file-customization-iface-for-vagrant-linux-cluster/4873/2>
* <https://stackoverflow.com/questions/53569760/kubernetes-v1-12-dashboard-is-running-but-timeout-occurred-while-accessing-it-vi>

The `--pod-network-cidr` already set in the deployment.

The `--iface=eth1` parameter can be added manually, for example:

```sh
kubectl edit -n kube-system daemonset.apps/kube-flannel-ds

spec:
  template:
    (...)
    spec:
      (...)
      containers:
      - args:
        - --ip-masq
        - --kube-subnet-mgr
        - --iface=eth1
      (...)
```

Patched by a dummy sed expression in `Vagrantfile`.

Status: Solved.

### Metrics server cannot start

On VirtualBox environment, metrics-server Pod is continously restarted, because it unable to fetch metrics from Kubelet, see the Pod log:

```text
I1227 08:35:24.688213       1 secure_serving.go:116] Serving securely on [::]:8443
E1227 08:36:54.703124       1 manager.go:111] unable to fully collect metrics: [unable to fully scrape metrics from source kubelet_summary:node1: unable to fetch metrics from Kubelet node1 (node1): Get https://node1:10250/stats/summary?only_cpu_and_memory=true: dial tcp: i/o timeout, unable to fully scrape metrics from source kubelet_summary:master: unable to fetch metrics from Kubelet master (master): Get https://master:10250/stats/summary?only_cpu_and_memory=true: dial tcp: i/o timeout, unable to fully scrape metrics from source kubelet_summary:node2: unable to fetch metrics from Kubelet node2 (node2): Get https://node2:10250/stats/summary?only_cpu_and_memory=true: dial tcp: i/o timeout]
```

A parameter `--kubelet-preferred-address-types=InternalIP` added the the deployment.

Status: Solved.

### Ephemeral Debug Containers

Does not work.

More info:

* <https://github.com/kubernetes-sigs/kind/issues/1210>
* <https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/kubelet-integration/>
* <https://alexsimonjones.medium.com/kubectl-debug-time-to-say-goodbye-to-baking-diagnostic-tools-into-your-containers-47f6802d982b>
* <https://cdn.lbryplayer.xyz/api/v3/streams/free/debugpod/fea38048fe9f5648149ff6c1798afc34add1c77f/60d4df>
* <https://cdn.lbryplayer.xyz/api/v3/streams/free/debugpod/fea38048fe9f5648149ff6c1798afc34add1c77f/60d4df>

Finally, it was successful, see `Vagrantfile`.

Status: Solved.

### Vagrant in docker

If Vagrant is running in Docker (see: `alias vagrant='docker run ...`), the `vagrant ssh master -c ...` does not work.

Solution: use `vagrant ssh master -- ...`

Status: Solved.

### KVM BIOS cannot boot

KVM BIOS cannot boot newer Ubuntu images.

Workaround: using older box version. Example for removing latest 18.04 box and downloading older:

```sh
vagrant box remove peru/ubuntu-18.04-server-amd64
vagrant box add peru/ubuntu-18.04-server-amd64 --box-version 20201203.01 --provider libvirt
```

Status: Workaround
