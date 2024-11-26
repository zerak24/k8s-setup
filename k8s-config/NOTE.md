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

  * if use `--upload-certs` when init cluster, join must have `certificateKey`
  * certs secret will expires use `kubeadm init phase upload-certs --upload-certs --config init.yaml` and get `certificateKey` or just forgot `certificateKey` use `kubeadm certs certificate-key`
# Join Worker Node
  * comment `cluster.etcd`
  * comment `cluster.controlPlane`
# Upgrade Cluster
  * comment `cluster.node`
  * comment `cluster.etcd`
  * comment `cluster.controlPlane`