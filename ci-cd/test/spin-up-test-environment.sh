#!/usr/bin/bash -e

usage()
{
  echo "Usage: $0 [options] [-- tfvar files]
  -o | --os-image             The OS image to use for the VMs.
                              Default is 'ubuntu-24.04'.
                              Valid values are:
                                centos9
                                centos10
                                ubuntu-24.04
                                ubuntu-25.10
                              Environment variable: OS_IMAGE
  -u | --url                  The URL to download the OS image from.
                              Default is the official cloud image URL.
                              Environment variable: URL
  -h | --help                 Shows this same thing.

Examples:
  # Use default values
  $0

  # Specify all options
  $0 -o centos9 \\
    -u https://example.com/custom-centos-image.qcow2 \\
    -- \\
    ../example-hooks/registry-mirrors/post_proxies/test.tfvars

  # Using Environment Variables:
    export OS_IMAGE=centos9
    export URL=https://example.com/custom-centos-image.qcow2
    $0 \\
    -- \\
    ../example-hooks/registry-mirrors/post_proxies/test.tfvars
"
  exit 2
}

# Gets the command line options and sets global variables
#   get_options "$@"
function get_options() {
  # Store the command line arguments as a variable
  PARSED_ARGUMENTS=$(getopt -a -n "$0" \
                     -o o:u:h \
                     --long os-image:,url:,help \
                     -- "$@")
  VALID_ARGUMENTS=$?

  # Make sure some arguments were passed in
  if [ "$VALID_ARGUMENTS" != "0" ]
  then
    usage
  fi

  eval set -- "$PARSED_ARGUMENTS"

  # Parse the command line options
  while :
  do
    case "$1" in
      -o | --os-image)            OS_IMAGE="$2"; shift 2 ;;
      -u | --url)                 URL="$2"; shift 2 ;;
      -h | --help)                usage;;
      --)                         shift; break ;;
      *)                          echo "Unexpected option: $1"; usage ;;
    esac
  done

  # Make sure the necessary commands exist
  if ! which "tofu" > /dev/null 2>&1
  then
    echo "Please install: tofu"
    exit 1
  fi

  # Download cloud image if not already present
  OS_IMAGE=${OS_IMAGE:-ubuntu-24.04}
  if [ "${OS_IMAGE}" = "centos9" ]
  then
    IMAGE_URL="${URL:-http://assets.cyclops-assets/os-images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2}"
  elif [ "${OS_IMAGE}" = "centos10" ]
  then
    IMAGE_URL="${URL:-http://assets.cyclops-assets/os-images/CentOS-Stream-GenericCloud-10-latest.x86_64.qcow2}"
  elif [ "${OS_IMAGE}" = "ubuntu-24.04" ]
  then
    IMAGE_URL="${URL:-http://assets.cyclops-assets/os-images/noble-server-cloudimg-amd64.img}"
  elif [ "${OS_IMAGE}" = "ubuntu-25.10" ]
  then
    IMAGE_URL="${URL:-http://assets.cyclops-assets/os-images/questing-server-cloudimg-amd64.img}"
  else
    echo "Unsupported os-image: ${OS_IMAGE}"
    exit 1
  fi
}

get_options "$@"

cd tofu

tofu init
tofu apply \
  -auto-approve \
  -var="image_url=${IMAGE_URL}" \
  -var="hostname_prefix=gh-${GITHUB_RUN_NUMBER:--vm}"

echo "The VMs are up and running. You can SSH into them using the following command:"

# get the hostnames from the tofu output
TOFU_OUTPUT=$(tofu output -json -show-sensitive)
PROXY_HOSTNAME=$(echo "${TOFU_OUTPUT}" | jq -r '.information.value.proxy.hostname')
CONTROL_PLANE_HOSTNAMES=$(echo "${TOFU_OUTPUT}" | jq -r '.information.value.control_planes[].hostname')
WORKER_NODE_HOSTNAMES=$(echo "${TOFU_OUTPUT}" | jq -r '.information.value.workers[].hostname')
PASSWORD=$(echo "${TOFU_OUTPUT}" | jq -r '.information.value.vm_password')

echo "Proxy VM: ssh ubuntu@${PROXY_HOSTNAME}"
for HOSTNAME in ${CONTROL_PLANE_HOSTNAMES}; do
  echo "Control Plane VM: ssh ubuntu@${HOSTNAME}"
done
for HOSTNAME in ${WORKER_NODE_HOSTNAMES}; do
  echo "Worker Node VM: ssh ubuntu@${HOSTNAME}"
done

cd ..
# execute the post-init-playbook
ansible-playbook -i inventory.yaml -i tofu/vars.yaml post-init-playbook/playbook.yaml

echo "VM Password is '${PASSWORD}'"
