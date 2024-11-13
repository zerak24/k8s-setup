#! /bin/bash

# prepare essential file

mkdir -p /etc/systemd/system/kubelet.service.d
mkdir -p /etc/kubernetes/pki/etcd
wget http://$2/file/etcd/ca.crt -O /etc/kubernetes/pki/etcd/ca.crt
wget http://$2/file/etcd/ca.key -O /etc/kubernetes/pki/etcd/ca.key
wget http://$2/file/kubelet-etcd-$1.yaml -O /etc/systemd/system/kubelet.service.d/kubelet.conf
wget http://$2/file/init-etcd-$1.yaml -O init-etcd.yaml

cat << EOF > /etc/systemd/system/kubelet.service.d/20-etcd-service-manager.conf
[Service]
ExecStart=
ExecStart=/usr/bin/kubelet --config=/etc/systemd/system/kubelet.service.d/kubelet.conf
Restart=always
EOF

systemctl daemon-reload
systemctl restart kubelet

# init essential certs

kubeadm init phase certs etcd-server --config=init-etcd.yaml
kubeadm init phase certs etcd-peer --config=init-etcd.yaml
kubeadm init phase certs etcd-healthcheck-client --config=init-etcd.yaml
kubeadm init phase certs apiserver-etcd-client --config=init-etcd.yaml

# init cluster

kubeadm init phase etcd local --config=init-etcd.yaml

# healthcheck optional

# ETCDCTL_API=3 etcdctl \
# --cert /etc/kubernetes/pki/etcd/peer.crt \
# --key /etc/kubernetes/pki/etcd/peer.key \
# --cacert /etc/kubernetes/pki/etcd/ca.crt \
# --endpoints https://192.168.180.129:2379 endpoint health