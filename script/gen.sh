#! /bin/bash

# default values
dir=$(pwd)
template_dir="./optional-config"
additional_args=""

function check_hostname() {
  set -e

  if [ -z ${hostname} ]
  then
    echo "hostname is not define"
    exit 1
  fi

  set +e
}

function check_file() {
  set -e

  if [ -z ${file} ]
  then
    echo "file is not define"
    exit 1
  fi

  set +e
}

function help_func() {
  set -e

  cat << EOF
usage: command [action] [flags]

help:
  print this help
cluster:
  generate cluster config file
  --hostname  : machine's hostname
  --dir       : directory store the ouput file (default: $(pwd))
  --file      : values file to generate configuration file
  --kubelet   : generate separately kubelet config file
  --ca-cert   : path of ca root cert
  --token     : join token
  --certs-keys: keys for download nessessary cluster certs when init cluster with --upload-certs
lb:
  generate load balancer nginx config file
  --dir    : directory store the ouput file (default: $(pwd))
  --servers: list endpoints of api server separate with comma
  --lb-port: load balancer serve port
dns:
  copy template file
  --dir: directory store the ouput file (default: $(pwd))
  * note: reconfig file db.internal
EOF

  set +e
}

function gen_cluster() {
  set -e

  check_hostname
  check_file

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

  set +e
}

function gen_nginx_lb() {
  set -e
  template_nginx="${template_dir}/lb-nginx/kubernetes-api-lb.conf.tpl"

  cat ${template_nginx} | lb_port=${lb_port} envsubst > ${dir}/kubernetes-api-lb.conf

  IFS=","
  for v in ${servers}
  do
    sed -i "s/^#######/\tserver ${v};\n#######/" ${dir}/kubernetes-api-lb.conf
  done

  sed -i "s/^#######//" ${dir}/kubernetes-api-lb.conf
  sed -i "/^$/d" ${dir}/kubernetes-api-lb.conf

  unset IFS

  set +e
}

function gen_internal_dns() {
  set -e

  file_db="${template_dir}/internal-dns/named.conf.internal"
  template_dns="${template_dir}/internal-dns/db.internal"
  
  cp ${file_db} ${template_dns} ${dir}

  set +e
}

action=$1
shift
params="$@"

while (( "$#" )); do
  case "$1" in
    --hostname)
      hostname=$2
      shift 2
      ;;
    --file)
      file=$2
      shift 2
      ;;
    --dir)
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
      additional_args="${additional_args}--set cluster.node.join.caCertHashes={sha256:$(cat ${ca_crt} | \
          openssl x509 -pubkey  | \
          openssl rsa -pubin -outform der 2>/dev/null | \
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
    --lb-port)
      lb_port=$2
      shift 2
      ;;
    --servers)
      servers=$2
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

mkdir -p ${dir}

case ${action} in
  help)
  help_func
  exit 0
  ;;
  cluster)
  gen_cluster
  exit 0
  ;;
  lb)
  gen_nginx_lb
  exit 0
  ;;
  dns)
  gen_internal_dns
  exit 0
  ;;
  *)
  echo "invalid action"
  exit 0
  ;;
esac
