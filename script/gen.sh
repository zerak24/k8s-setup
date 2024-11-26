#! /bin/bash

function check() {
  set -e

  if [ -z ${hostname} ]
  then
    echo "hostname is not define"
    exit 0
  fi

  if [ -z ${file} ]
  then
    echo "file is not define"
    exit 0
  fi

  set +e
}

function help_fn() {
  set -e

  cat << EOF
usage: command [flags]

  -h|--help     : print this help
  -n|--hostname : machine's hostname
  -d|--dir      : directory store the ouput file
     --kubelet  : generate separately kubelet config file
EOF

  set +e
}

# default values
dir=$(pwd)
additional_args=""

while (( "$#" )); do
  case "$1" in
    -h|--help)
      help_fn
      exit 0
      ;;
    -n|--hostname)
      hostname=$2
      shift 2
      ;;
    -f|--file)
      file=$2
      shift 2
      ;;
    -d|--dir)
      dir=$2
      shift 2
      ;;
    --kubelet)
      kubelet=true
      shift 1
      ;;
    --ca-crt)
      ca_crt=$2
      shift 2
      additional_args="${additional_args}--set cluster.node.join.caCertHashes={sha256:$(cat ${ca_crt} | openssl x509 -pubkey  | openssl rsa -pubin -outform der 2>/dev/null | \
          openssl dgst -sha256 -hex | sed 's/^.* //')} "
      ;;
    --token)
      token=$2
      shift 2
      additional_args="${additional_args}--set cluster.node.join.token=${token} "
      ;;
    --certs-key)
      certs_key=$2
      shift 2
      additional_args="${additional_args}--set cluster.controlPlane.certificateKey=${certs_key} "
      ;;
    *)
      shift
      ;;
  esac
done

mkdir -p ${dir}

if [ ${kubelet} ]
then
  kubelet_command="helm template ./k8s-config \
  -s templates/kubelet.yaml \
  -f ${file} \
  --set cluster.etcd.local.kubelet=true > ${dir}/kubelet-${hostname}.yaml"
  eval ${kubelet_command}
fi

if [ ! -z ${file} ] && [ ! -z ${hostname} ]
then
  command="helm template ./k8s-config \
  -f ${file} ${additional_args} > ${dir}/${hostname}.yaml"
  eval ${command}
fi