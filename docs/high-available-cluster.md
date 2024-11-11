### Setup cluster

- `helm template ./k8s-config -f ./value-files/cluster.yaml > ./file/initCluster.yaml`
- `kubeadm init --config ./file/initCluster.yaml --upload-certs`
- `helm template ./k8s-config -f ./value-files/cluster.yaml > ./file/initCluster.yaml` (note: enable joinControlPlane)