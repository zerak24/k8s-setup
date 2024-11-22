#! /bin/bash

# variables

RUNTIME_CONTAINER=unix:///var/run/containerd/containerd.sock
K8S_VERSION=v1.31
CNI_VERSION=v1.6.0

# turn off swap

sed -i 's/\/swap/#\/swap/1' /etc/fstab
swapoff -a

# install tools

apt-get update
apt-get -y install net-tools apt-transport-https ca-certificates curl gpg

# enable ip_forward

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
EOF
sudo sysctl --system

echo br_netfilter | tee /etc/modules-load.d/kubernetes.conf

# add apt key rings

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

curl -fsSL https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list

apt-get update

# setup containerd && enable plugin cri

apt-get install -y containerd.io
apt-mark hold containerd.io
sed -i 's/disabled_plugins/#disabled_plugins/g' /etc/containerd/config.toml
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
sleep 1
crictl config --set runtime-endpoint=${RUNTIME_CONTAINER}
systemctl enable --now containerd

wget https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/cni-plugins-linux-amd64-${CNI_VERSION}.tgz
mkdir -p /opt/cni/bin
tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-${CNI_VERSION}.tgz
rm cni-plugins-linux-amd64-${CNI_VERSION}.tgz
sleep 1

# setup k8s tools

apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
sleep 1
systemctl enable --now kubelet

