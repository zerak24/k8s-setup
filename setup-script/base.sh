#! /bin/bash

apt-get update

# turn off swap

sed -i 's/\/swap/#\/swap/1' /etc/fstab
swapoff -a

# install tools

apt-get -y install net-tools apt-transport-https ca-certificates curl gpg

# add apt key rings

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list

apt-get update

# setup containerd

apt-get install -y containerd.io
apt-mark hold containerd.io
sleep 1
systemctl enable --now containerd

wget https://github.com/containernetworking/plugins/releases/download/v1.6.0/cni-plugins-linux-amd64-v1.6.0.tgz
mkdir -p /opt/cni/bin
tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-v1.6.0.tgz
rm cni-plugins-linux-amd64-v1.6.0.tgz
sleep 1

# setup k8s v1.31 tools

apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
sleep 1
systemctl enable --now kubelet

# enable ip_forward

sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sysctl -p
