### Setup etcd cluster

_note: this section allow you to build external etcd_

- `helm template ./k8s-config -f ./value-files/etcd-0.yaml --set generate.etcdKubelet=true > ./file/etcdKubelet.yaml`
- `helm template ./k8s-config -f ./value-files/etcd-0.yaml --set generate.etcdInit=true --set generate.etcdCluster=true > ./file/etcdCluster-248.yaml` (note: change advertiseAddress for each host)
- copy `./setup-script/etcd-cluster.sh`, `./file/etcdKubelet.yaml`, `./file/etcdCluster-248.yaml`, `ca.crt` and `ca.key` in the previous step to etcd host (store in same folder)
- access to etcd host run `./setup-script/etcd-cluster.sh` (note: commen disabled_plugins in /etc/containerd/config.toml)
