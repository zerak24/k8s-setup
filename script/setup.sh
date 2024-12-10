#! /bin/bash

# default setup
runtime_container=unix:///var/run/containerd/containerd.sock
k8s_version=v1.31
cni_version=v1.6.0
lb_port=9000
server_port=6443
calico_version=v3.29.1

function check_hostname() {
  set -e

  if [ -z ${hostname} ]
  then
    echo "hostname is not define"
    exit 0
  fi

  set +e
}

function check_pod_cidr() {
  set -e

  if [ -z ${pod_cidr} ]
  then
    echo "pod cidr is not define"
    exit 0
  fi

  set +e
}

function check_url() {
  set -e

  if [ -z ${url} ]
  then
    echo "url is not define"
    exit 0
  fi

  set +e
}

function help_func() {
  set -e

  cat << EOF
usage: command [action] [flags]

help:
  print this help
base:
  setup base component
  --runtime-container: unix socket of runtime container endpoint (default: ${runtime_container})
  --k8s-version      : kubernetes version (default: ${k8s_version})
  --cni-version      : cni plugins version (default: ${cni_version})
etcd:
  setup etcd for external etcd cluster
  --url      : url for download components (eg: https://example.com/file)
  --hostname : machine's hostname
control:
  setup control plane
  --url      : url for download components (eg: https://example.com/file)
  --hostname : machine's hostname
  --nginx    : nginx load balancer enable
cni:
  install calico cni plugins for kubernetes cluster (note: apply to current kubernetes context)
  --calico-version: calico version (default: ${calico_version})
  --pod-cidr      : pod cidr in kubernetes cluster configuration
lb:
  setup kubernetes api load balancer with nginx (optional)
dns:
  setup internal dns (optional)
  * note: remember to add nameserver to /etc/resolve.conf
EOF

  set +e
}

function base() {
  set -e

  sed -i 's/\/swap/#\/swap/1' /etc/fstab
  swapoff -a

  apt-get update
  apt-get -y install net-tools apt-transport-https ca-certificates curl gpg

  cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
EOF
  sudo sysctl --system

  echo br_netfilter | tee /etc/modules-load.d/kubernetes.conf

  if [ -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg ]
  then
    rm -rf "/etc/apt/keyrings/kubernetes-apt-keyring.gpg"
  fi

  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null

  curl -fsSL https://pkgs.k8s.io/core:/stable:/${k8s_version}/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${k8s_version}/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list

  apt-get update

  apt-get install -y containerd.io
  apt-mark hold containerd.io
  sed -i 's/disabled_plugins/#disabled_plugins/g' /etc/containerd/config.toml
  containerd config default > /etc/containerd/config.toml
  sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

  wget https://github.com/containernetworking/plugins/releases/download/${cni_version}/cni-plugins-linux-amd64-${cni_version}.tgz
  mkdir -p /opt/cni/bin
  tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-${cni_version}.tgz
  rm cni-plugins-linux-amd64-${cni_version}.tgz

  systemctl enable --now containerd

  apt-get install -y kubelet kubeadm kubectl
  apt-mark hold kubelet kubeadm kubectl

  systemctl enable --now kubelet
  
  crictl config --set runtime-endpoint=${runtime_container}
  systemctl restart containerd
  systemctl restart kubelet

  set +e
}

function etcd() {
  set -e

  check_hostname
  check_url

  mkdir -p /etc/systemd/system/kubelet.service.d
  mkdir -p /etc/kubernetes/pki/etcd

  wget ${url}/ca.crt -O /etc/kubernetes/pki/etcd/ca.crt
  wget ${url}/ca.key -O /etc/kubernetes/pki/etcd/ca.key
  wget ${url}/kubelet-${hostname}.yaml -O /etc/systemd/system/kubelet.service.d/kubelet.conf
  wget ${url}/${hostname}.yaml -O init.yaml

  cat << EOF > /etc/systemd/system/kubelet.service.d/20-etcd-service-manager.conf
[Service]
ExecStart=
ExecStart=/usr/bin/kubelet --config=/etc/systemd/system/kubelet.service.d/kubelet.conf
Restart=always
EOF

  systemctl daemon-reload
  systemctl restart kubelet

  kubeadm init phase certs etcd-server --config=init.yaml
  kubeadm init phase certs etcd-peer --config=init.yaml
  kubeadm init phase certs etcd-healthcheck-client --config=init.yaml
  kubeadm init phase certs apiserver-etcd-client --config=init.yaml

  kubeadm init phase etcd local --config=init.yaml

  set +e
}

function control() {
  set -e

  check_hostname
  check_url

  mkdir -p /etc/kubernetes/pki/etcd

  wget ${url}/ca.crt -O /etc/kubernetes/pki/etcd/ca.crt
  wget ${url}/apiserver-etcd-client.crt -O /etc/kubernetes/pki/apiserver-etcd-client.crt
  wget ${url}/apiserver-etcd-client.key -O /etc/kubernetes/pki/apiserver-etcd-client.key
  wget ${url}/${hostname}.yaml -O init.yaml

  kubeadm init --config=init.yaml --upload-certs

  set +e
}

function calico_cni() {
  set -e

  check_pod_cidr

  kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/${calico_version}/manifests/tigera-operator.yaml
  curl https://raw.githubusercontent.com/projectcalico/calico/${calico_version}/manifests/custom-resources.yaml -O
  sed -i "s/192.168.0.0\/16/${cidr_prefix}\/${cidr_block}/" custom-resources.yaml
  kubectl apply -f custom-resources.yaml

  set +e
}

function k8s_api_lb() {
  set -e

  check_url

  apt-get update
  apt-get install -y nginx libnginx-mod-stream

  wget ${url}/kubernetes-api-lb.conf -O /etc/nginx/conf.d/kubernetes-api-lb.conf

  sed -i 's/include \/etc\/nginx\/conf.d\/\*.conf/# include \/etc\/nginx\/conf.d\/\*.conf/g' /etc/nginx/nginx.conf

  if [ $(cat /etc/nginx/nginx.conf | grep "kubernetes-api-lb.conf" | wc -l) -eq 0 ]
  then
    echo "include /etc/nginx/conf.d/kubernetes-api-lb.conf;" >> /etc/nginx/nginx.conf
  fi

  systemctl restart nginx

  set +e
}

function internal_dns() {
  set -e
  
  check_url

  apt-get update
  apt-get install -y bind9 bind9utils bind9-doc

  sed -i "s/-u bind/-u bind -4/g" /etc/default/named

  systemctl restart bind9

  wget ${url}/named.conf.internal -O /etc/bind/named.conf.internal
  wget ${url}/db.internal -O /etc/bind/db.internal

  systemctl restart bind9
  
  set +e
}

action=$1
shift
params="$@"

while (( "$#" )); do
  case "$1" in
    --runtime-container)
      runtime_container=$2
      shift 2
      ;;
    --k8s-version)
      k8s_version=$2
      shift 2
      ;;
    --cni-version)
      cni_version=$2
      shift 2
      ;;
    --hostname)
      hostname=$2
      shift 2
      ;;
    --url)
      url=$2
      shift 2
      ;;
    --calico-version)
      calico_version=$2
      shift 2
      ;;
    --pod-cidr)
      pod_cidr=$2
      cidr_prefix=$(echo $pod_cidr | cut -d "/" -f1)
      cidr_block=$(echo $pod_cidr | cut -d "/" -f2)
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

case ${action} in
  help)
  help_func
  exit 0
  ;;
  base)
  base
  exit 0
  ;;
  etcd)
  etcd
  exit 0
  ;;
  control)
  control
  exit 0
  ;;
  cni)
  calico_cni
  exit 0
  ;;
  lb)
  k8s_api_lb
  exit 0
  ;;
  dns)
  internal_dns
  exit 0
  ;;
  *)
  echo "invalid action"
  exit 0
  ;;

esac