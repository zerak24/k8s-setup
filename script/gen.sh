#! /bin/bash
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

dir=$(pwd)

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
  -f ${file} > ${dir}/${hostname}.yaml"
  eval ${command}
fi