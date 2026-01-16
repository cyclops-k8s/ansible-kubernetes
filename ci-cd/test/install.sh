#!/usr/bin/bash -e

usage()
{
  echo "Usage: $0 [options] -- tfvar files
  -v | --version  Kubernetes version to install.
                  Default is the version specified in the terraform main.tf file.
  -h | --help     Shows this helpful usage statement.

    Examples:
        $0 -v 1.35
        $0 -- ../example-hooks/registry-mirrors/post_proxies/test.tfvars
"
  exit 2
}

# Store the command line arguments as a variable
PARSED_ARGUMENTS=$(getopt -a -n "$0" -o v:h --long version:,help -- "$@")
VALID_ARGUMENTS=$?

# Make sure some arguments were passed in
if [ "$VALID_ARGUMENTS" != "0" ];
then
  usage
fi

eval set -- "$PARSED_ARGUMENTS"

# Parse the command line options
while :
do
  case "$1" in
    -v | --version) export KUBERNETES_VERSION="$2"; shift 2 ;;
    -h | --help)    usage;;
    --)             shift; break ;;
    # If invalid options were passed, then getopt should have reported an error,
    # which we checked as VALID_ARGUMENTS when getopt was called...
    *)              echo "Unexpected option: $1"; usage ;;
  esac
done

#combine the rest of the arguments as tfvar files prefixed with -var-file=
TFVAR_FILES=()
for arg in "$@"
do
  if [ ! -f "${arg}" ]
  then
    echo "tfvar file does not exist: ${arg}"
    exit 1
  fi
  TFVAR_FILES+=("-var-file=${arg}")
done

echo "Running Terraform to generate inventory and configuration"
if [ -z "${KUBERNETES_VERSION}" ]
then
  echo "KUBERNETES_VERSION not set, using default from terraform variables"
else
  echo "Using KUBERNETES_VERSION=${KUBERNETES_VERSION}"
  export TF_VAR_kubernetes_version=${KUBERNETES_VERSION}
fi

cd tofu
tofu apply -auto-approve "${TFVAR_FILES[@]}"
cd ..

echo "Running the ansible playbook to install kubernetes"
ansible-playbook -i "inventory.yaml" -i tofu/vars.yaml ../../install.yaml
