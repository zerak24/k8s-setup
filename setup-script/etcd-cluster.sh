#! /bin/bash

## PREPARE KUBELET

mkdir -p /etc/systemd/system/kubelet.service.d

mv ./etcdKubelet.yaml /etc/systemd/system/kubelet.service.d/kubelet.conf

cat << EOF > /etc/systemd/system/kubelet.service.d/20-etcd-service-manager.conf
[Service]
ExecStart=
ExecStart=/usr/bin/kubelet --config=/etc/systemd/system/kubelet.service.d/kubelet.conf
Restart=always
EOF

systemctl daemon-reload
systemctl restart kubelet

## PREPARE CERTS

kubeadm init phase certs etcd-ca

# already have copy like this
# /etc/kubernetes/pki/etcd/ca.crt
# /etc/kubernetes/pki/etcd/ca.key

kubeadm init phase certs etcd-server --config=./etcdCluster.yaml
kubeadm init phase certs etcd-peer --config=./etcdCluster.yaml
kubeadm init phase certs etcd-healthcheck-client --config=./etcdCluster.yaml
kubeadm init phase certs apiserver-etcd-client --config=./etcdCluster.yaml

## INIT

sleep 1

kubeadm init phase etcd local --config=./etcdCluster.yaml

## CHECK HEALTH

# ETCDCTL_API=3 etcdctl \
# --cert /etc/kubernetes/pki/etcd/peer.crt \
# --key /etc/kubernetes/pki/etcd/peer.key \
# --cacert /etc/kubernetes/pki/etcd/ca.crt \
# --endpoints https://${HOST0}:2379 endpoint health