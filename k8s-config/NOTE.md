# Init Separately Etcd Cluster
  * comment `cluster.controlPlane`
  * comment `cluster.etcd.external`
  * set     `cluster.etcd.local.kubelet` to `true` to generate `KubeletConfiguration`
# Init Control Plane with External Etcd
  * comment `cluster.etcd.local`
# Init Control Plane stack with Etcd
  * comment `cluster.etcd.external`
# Join Control Plane Node
  * comment `cluster.etcd`

  *Note: if use `--upload-certs` when init cluster, join must have `certificateKey` if certs secret will expires use `kubeadm init phase upload-certs --upload-certs --config init.yaml` and get `certificateKey` or just forgot `certificateKey` use `kubeadm certs certificate-key`
# Join Worker Node
  * comment `cluster.etcd`
  * comment `cluster.controlPlane`
# Upgrade Cluster
  * comment `cluster.node`
  * comment `cluster.etcd`
  * comment `cluster.controlPlane`

  *Note: upgrade kubeadm first `apt-mark unhold kubeadm && apt-get update && apt-get install -y kubeadm=<new-version> && apt-mark hold kubeadm`, verify `kubeadm upgrade plan --config=upgrade.yaml`, apply `kubeadm upgrade apply --config=upgrade.yaml`, other control node `kubeadm upgrade node`
  *Note: drain node, `kubectl drain <node-name> --ignore-daemonsets`, upgrade kubelet, kubectl `apt-mark unhold kubelet kubectl && apt-get update && apt-get install -y kubelet=<new-version> kubectl=<new-version> && apt-mark hold kubelet kubectl`, reload kubelet `systemctl daemon-reload && systemctl restart kubelet`, uncordon node `kubectl uncordon <node-name>`
