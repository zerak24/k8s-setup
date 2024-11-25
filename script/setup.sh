#! /bin/bash

function help_func() {
  set -e

  cat << EOF
usage: command [action] [flags]

help:
  print this help
base:
  setup base component
  -r|--runtime-container: unix socket of runtime container endpoint (default: unix:///var/run/containerd/containerd.sock)
  -v|--k8s-version      : kubernetes version (default: v1.31)
  -c|--cni-version      : cni plugins version (default: v1.6.0)
etcd:
  setup etcd for external etcd cluster
  -u|--url      : url for download components (eg: https://example.com/file)
  -n|--hostname : machine's hostname
control:
  setup control plane
  -u|--url      : url for download components (eg: https://example.com/file)
  -n|--hostname : machine's hostname
     --nginx    : nginx load balancer enable
EOF

  set +e
}

function base() {
  set -e

  # default setup
  runtime_container=unix:///var/run/containerd/containerd.sock
  k8s_version=v1.31
  cni_version=v1.6.0

  while (( "$#" )); do
    case "$1" in
      -r|--runtime-container)
        runtime_container=$2
        shift 2
        ;;
      -v|--k8s-version)
        k8s_version=$2
        shift 2
        ;;
      -c|--cni-version)
        cni_version=$2
        shift 2
        ;;
      *)
        shift
        ;;
    esac
  done

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

  curl -fsSL https://pkgs.k8s.io/core:/stable:/${k8s_version}/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${k8s_version}/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list

  apt-get update

  # setup containerd && enable plugin cri
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

  # setup k8s tools
  apt-get install -y kubelet kubeadm kubectl
  apt-mark hold kubelet kubeadm kubectl

  systemctl enable --now kubelet
  
  # reload service
  crictl config --set runtime-endpoint=${runtime_container}
  systemctl restart containerd
  systemctl restart kubelet

  set +e
}

function etcd() {
  set -e

  while (( "$#" )); do
    case "$1" in
      -n|--hostname)
        hostname=$2
        shift 2
        ;;
      -u|--url)
        url=$2
        shift 2
        ;;
      *)
        shift
        ;;
    esac
  done

  # prepare essential file
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

  # init essential certs
  kubeadm init phase certs etcd-server --config=init.yaml
  kubeadm init phase certs etcd-peer --config=init.yaml
  kubeadm init phase certs etcd-healthcheck-client --config=init.yaml
  kubeadm init phase certs apiserver-etcd-client --config=init.yaml

  # init cluster
  kubeadm init phase etcd local --config=init.yaml

  set +e
}

function control() {
  set -e

  while (( "$#" )); do
    case "$1" in
      -n|--hostname)
        hostname=$2
        shift 2
        ;;
      -u|--url)
        url=$2
        shift 2
        ;;
      --nginx)
        nginx_enable=true
        shift
        ;;
      --lb-port)
        lb_port=$2
        shift 2
        ;;
      --server-port)
        server_port=$2
        shift 2
        ;;
      *)
        shift
        ;;
    esac
  done
  # nginx load balancer enable
  apt-get install -y nginx libnginx-mod-stream

  # config load balancer (TODO)
  cat << EOF >> /etc/nginx/nginx.conf
stream {
  upstream kubernetes_apis {
    least_conn;
    server localhost:${server_port};
  }
  server {
    listen ${lb_port};
    proxy_pass kubernetes_apis;
  }
}
EOF

  # prepare essential file
  mkdir -p /etc/kubernetes/pki/etcd

  wget ${url}/ca.crt -O /etc/kubernetes/pki/etcd/ca.crt
  wget ${url}/apiserver-etcd-client.crt -O /etc/kubernetes/pki/apiserver-etcd-client.crt
  wget ${url}/apiserver-etcd-client.key -O /etc/kubernetes/pki/apiserver-etcd-client.key
  wget ${url}/${hostname}.yaml -O init.yaml

  # init cluster
  kubeadm init --config=init.yaml --upload-certs

  set +e
}

action=$1
shift
params="$@"

case ${action} in
  help)
  help_func
  exit 0
  ;;
  base)
  base $params
  exit 0
  ;;
  etcd)
  etcd $params
  exit 0
  ;;
  control)
  control $params
  exit 0
  ;;
  *)
  exit 0
  ;;

esac