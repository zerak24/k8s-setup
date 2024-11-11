### Setup cluster

* external etcd step:

- copy `/etc/kubernetes/pki/etcd/ca.crt`, `/etc/kubernetes/pki/apiserver-etcd-client.crt` and `/etc/kubernetes/pki/apiserver-etcd-client.key` from any `etcd` host to `init control plane` host


* general step

- `helm template ./k8s-config -f ./value-files/cluster.yaml > ./file/initCluster-140.yaml`
- go to `init control plane` host run `kubeadm init --config ./file/initCluster-140.yaml --upload-certs`
- `helm template ./k8s-config -f ./value-files/cluster.yaml > ./file/initCluster-144.yaml` (note: enable joinControlPlane)
- go to `join control plane` host run `kubeadm join --config ./file/initCluster-144.yaml`