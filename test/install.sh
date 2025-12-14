#!/usr/bin/bash -e

usage()
{
  echo "Usage: $0

  [ ( -v # | --version ) #] [ -h | --help ]

Options:

  -v | --version  Kubernetes version to install.
                  Default is the version specified in the terraform main.tf file.
  -h | --help     Shows this helpful usage statement.
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

if [ -z "${DEVCONTAINER}" ]
then
    echo "This script is intended to only be run inside a devcontainer."
    exit 1
fi

if ! pgrep -f "^qemu-system-x86_64" > /dev/null
then
  echo "VMs are not running, please run spin-up-test-environment.sh first."
  exit 1
fi

which terraform && CMD=terraform
which tofu && CMD=tofu

if [ "${CMD}" == "" ]
then
  echo "terraform or tofu needs to be installed"
  echo 1
fi

echo "VMs are running."

echo "Running Terraform to generate inventory and configuration"
if [ -z "${KUBERNETES_VERSION}" ]
then
  echo "KUBERNETES_VERSION not set, using default from terraform variables"
else
  echo "Using KUBERNETES_VERSION=${KUBERNETES_VERSION}"
  export TF_VAR_kubernetes_version=${KUBERNETES_VERSION}
fi

${CMD} init
${CMD} apply -auto-approve

echo "Running the ansible playbook to install kubernetes"
ansible-playbook -i "inventory_${CMD}.yaml" -i vars.yaml ../install.yaml
