#!/usr/bin/bash -e

usage()
{
  echo "Usage: $0 [options]
  -c | --conformance          Build the environment for running conformance tests
  -d | --domain               The domain to use for the VMs.
                              Default is k8s.local
                              Environment variable: DOMAIN
  -o | --os-image             The OS image to use for the VMs.
                              Default is 'ubuntu-26.04'.
                              Valid values are:
                                centos9
                                centos10
                                ubuntu-24.04
                                ubuntu-26.04
                              Environment variable: OS_IMAGE
  -v | --ovmf-file            The OVMF file to use for UEFI booting.
                              Default is /usr/share/OVMF/OVMF_CODE_4M.fd
                              Environment variable: OVMF_FILE
  -p | --ip-prefix            The IP prefix to use for the VMs.
                              Default is 10.255.254
                              Environment variable: IP_PREFIX
  -s | --ssh-public-key-file  The SSH public key file to use for VM access.
                              Default is ~/.ssh/devcontainer.id_rsa.pub
                              Environment variable: SSH_PUBLIC_KEY_FILE
  -t | --temp-dir             The temporary directory to store VM files.
                              Default is ./.temp
                              Environment variable: TEMP_DIR
  -u | --url                  The URL to download the OS image from.
                              Default is the official cloud image URL.
                              Environment variable: URL
  -h | --help                 Shows this same thing.

Examples:
  # Use default values
  $0

  # Specify all options
  $0 -d somethingrandom.tld \\
    -o centos9 \\
    -p 10.251.251 \\
    -s ~/.ssh/k8s.id.pub \\
    -t /tmp/k8s-vms \\
    -u https://example.com/custom-centos-image.qcow2 \\
    -v ~/ovmf.fd

  # Using Environment Variables:
    export DOMAIN=somethingrandom.tld
    export OS_IMAGE=centos9
    export IP_PREFIX=10.251.251
    export SSH_PUBLIC_KEY_FILE=~/.ssh/k8s.id.pub
    export TEMP_DIR=/tmp/k8s-vms
    export URL=https://example.com/custom-centos-image.qcow2
    export OVMF_FILE=~/ovmf.fd
    $0

  .local directory:
  This is a directory that is excluded from the git repository and can be used to provide additional configuration for the VMs or playbook.
  Examples of things you can put in there are things like additional configuration for the playbook when ran or local overrides for
  environment specific value, like apt repositories url's.
  You can also place a user-data.txt and network.txt files in there to have additional cloud-init user data and network configuration applied
  to the VMs when they are created.
  The configured user-data and network cloud init files are piped through the contents of those files in the yq command that configures them.
  This is useful for adding additional users, packages, or network interfaces to the VMs without having to modify this script or anything that
  would be checked in to the git repository.
"
  exit 2
}

# This creates a qemu virtual machine.
# The create_vm function is called by passing several arguments.
# create_vm <hostname> <ssh port> <4th octect of IPv4> <memory size> <hdd size> <additional ports>
#   hostname            Required. Name of the virtual machine. Not the FQDN.
#   ssh_port            Required. Port to open on localhost to forward to port 22 on the virtual machine.
#   4th octect of IPv4  Required. Last octect of the IPv4 address. Also used for the MAC address.
#   memory size         Required. Size, in gigabytes, of memory to give the virtual machine. Do not append "G".
#   hdd size            Required. Size, in gigabytes, of hard disk size to give the virtual machine. Do not append "G".
#   additional ports    Optional. Additional port forwarding configuration to append. Example ",hostfwd=tcp::6443-:6443"
# For example:
#   create_vm px 2021 11 2 2 10 ",hostfwd=tcp::6443-:6443"
function create_vm() {
  local LOCAL_IP
  local name=$1
  local ssh_port=$2
  local ip=$3
  local cpu_num=$4
  local mem_size=$5
  local hdd_size=$6
  local additional_forwarding=$7

  LOCAL_IP=$(ip -j address | jq '.[] | select(.ifname=="eth0") | .addr_info[] | select(.family=="inet") | .local' -r)
  MTU=$(ip -j address | jq '.[] | select(.ifname=="eth0").mtu')

  echo "Creating virtual machine: ${name}"
  echo "  SSH Port: ${ssh_port}"
  echo "  IP: ${ip}"
  echo "  Local IP: ${LOCAL_IP}"
  echo "  MTU: ${MTU}"
  echo "  CPU: ${cpu_num}"
  echo "  Mem: ${mem_size}"
  echo "  HDD: ${hdd_size}"
  echo "  Additional Ports: ${additional_forwarding}"

  # Clean any previous virtual machine files
  rm -f "${TEMP_DIR}/${name}"*

  # Create empty cloud-init files
  echo "#cloud-config" > "${TEMP_DIR}/${name}.user-data"
  echo "" >> "${TEMP_DIR}/${name}.user-data"
  echo "#cloud-config" > "${TEMP_DIR}/${name}.network"
  echo "" >> "${TEMP_DIR}/${name}.network"

  ADDITIONAL_USERDATA_CONFIG="."
  ADDITIONAL_NETWORK_CONFIG="."
  if [ -f .local/user-data.txt ]
  then
    ADDITIONAL_USERDATA_CONFIG=" | $(cat .local/user-data.txt)"
  fi
  if [ -f .local/network.txt ]
  then
    ADDITIONAL_NETWORK_CONFIG=" | $(cat .local/network.txt)"
  fi

  # Update cloud-init files
  SSH_PUBLIC_KEY=$(cat "${SSH_PUBLIC_KEY_FILE}")
  cat cloud-init/user-data | \
    yq --yaml-output \
      ".hostname = \"${name}\" | \
       .fqdn = \"${name}.${DOMAIN}\" | \
       .users[0].ssh_authorized_keys = [\"${SSH_PUBLIC_KEY}\"] | \
       ${ADDITIONAL_USERDATA_CONFIG}" \
    >> "${TEMP_DIR}/${name}.user-data"

  # Set MAC addresses and IP configuration in network config
  MAC0=$(printf "52:54:00:00:00:%02x" "${ip}")
  MAC1=$(printf "52:54:00:00:01:%02x" "${ip}")
  cat cloud-init/network | \
    yq --yaml-output \
      ".network.ethernets.eth0.match.macaddress = \"${MAC0}\" | \
       .network.ethernets.eth0.nameservers.search = [ \"${DOMAIN}\" ] | \
       .network.ethernets.eth0.nameservers.addresses = [\"${LOCAL_IP}\"] | \
       .network.ethernets.eth0.mtu = ${MTU} | \
       .network.ethernets.eth1.match.macaddress = \"${MAC1}\" | \
       .network.ethernets.eth1.addresses += [\"${IP_PREFIX}.${ip}/24\"] | \
       ${ADDITIONAL_NETWORK_CONFIG}" \
    >> "${TEMP_DIR}/${name}.network"

  # Create the cloud-init iso
  cloud-localds "${TEMP_DIR}/${name}.cloud-init.iso" "${TEMP_DIR}/${name}.user-data" -N "${TEMP_DIR}/${name}.network" > /dev/null

  # Create the virtual machine hard drive
  echo "Creating VM ${name} on port ${ssh_port}..."
  BASE_IMAGE=$(basename "${IMAGE_FILE}")
  qemu-img create -b "${BASE_IMAGE}" -F qcow2 -f qcow2 "${TEMP_DIR}/${name}.img" "${hdd_size}G"


  # Qemu needs permissions to write to the drive files
  chmod o+w "${TEMP_DIR}/${name}.img"
  QEMU_BOOT_ARGS=""

  if [ "${USE_UEFI}" = "true" ]
  then
    # UEFI boot (Ubuntu)
    OVMF_CODE_BASENAME=$(basename "${OVMF_FILE}")
    QEMU_BOOT_ARGS="-drive if=pflash,format=raw,readonly=on,file=${TEMP_DIR}/${OVMF_CODE_BASENAME} \
      -drive if=pflash,format=raw,file=${TEMP_DIR}/${name}.ovmf_vars_4m.fd \
      -smbios type=0,uefi=on"
    cp /usr/share/OVMF/OVMF_VARS_4M.fd "${TEMP_DIR}/${name}.ovmf_vars_4m.fd"
    # Qemu needs permissions to write to the UEFI vars file
    chmod o+w "${TEMP_DIR}/${name}.ovmf_vars_4m.fd"
  fi
  if [ -e /dev/kvm ]
  then
    echo "KVM acceleration is available."
    ACCELERATOR="accel=kvm"
    CPU='host'
    ENABLE_KVM="-enable-kvm"
  else
    echo "KVM acceleration is NOT available. Performance may be slow."
    ACCELERATOR="accel=tcg"
    CPU='max'
    ENABLE_KVM=""
  fi
  # shellcheck disable=SC2086
  # Create/start the virtual machine
  sudo -b qemu-system-x86_64 \
      -boot menu=off \
      -cdrom "${TEMP_DIR}/${name}.cloud-init.iso" \
      -cpu "${CPU}" \
      ${QEMU_BOOT_ARGS} \
      -drive file="${TEMP_DIR}/${name}.img" \
      ${ENABLE_KVM} \
      -device virtio-net-pci,netdev=net0,mac="${MAC0}" \
      -device virtio-net-pci,netdev=net1,mac="${MAC1}" \
      -m "${mem_size}G" \
      -machine ${ACCELERATOR},type=q35 \
      -nographic \
      -netdev user,id=net0,hostfwd="tcp::${ssh_port}-:22${additional_forwarding}" \
      -netdev socket,id=net1,mcast=230.0.0.1:1234 \
      -smp "${cpu_num}" 1>"${TEMP_DIR}/${name}.stdout.log" 2>"${TEMP_DIR}/${name}.stderr.log"

  # Allow the virtual machine some time to boot
  sleep 3
}

# Gets the command line options and sets global variables
#   get_options "$@"
function get_options() {
  # Store the command line arguments as a variable
  PARSED_ARGUMENTS=$(getopt -a -n "$0" \
                     -o o:s:t:d:p:u:v:h:c \
                     --long os-image:,ssh-public-key-file:,temp-dir:,domain:,ip-prefix:,url:,ovmf-file:,help,conformance \
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
      -c | --conformance)         CONFORMANCE=true; shift ;;
      -d | --domain)              DOMAIN="$2"; shift 2 ;;
      -p | --ip-prefix)           IP_PREFIX="$2"; shift 2 ;;
      -o | --os-image)            OS_IMAGE="$2"; shift 2 ;;
      -S | --ssh-public-key-file) SSH_PUBLIC_KEY_FILE="$2"; shift 2 ;;
      -t | --temp-dir)            TEMP_DIR="$2"; shift 2 ;;
      -u | --url)                 URL="$2"; shift 2 ;;
      -v | --ovmf-file)           OVMF_FILE="$2"; shift 2 ;;
      -h | --help)                usage;;
      --)                         shift; break ;;
      *)                          echo "Unexpected option: $1"; usage ;;
    esac
  done

  CONFORMANCE=${CONFORMANCE:-false}
  SSH_PUBLIC_KEY_FILE=${SSH_PUBLIC_KEY_FILE:-~/.ssh/devcontainer.id_rsa.pub}
  TEMP_DIR=${TEMP_DIR:-.temp}
  DOMAIN=${DOMAIN:-k8s.local}
  IP_PREFIX=${IP_PREFIX:-10.255.254}
  OVMF_FILE=${OVMF_FILE:-/usr/share/OVMF/OVMF_CODE_4M.fd}

  # Check if running in a devcontainer
  if [ -z "${DEVCONTAINER}" ]
  then
    echo "This script is intended to only be run inside a devcontainer."
    exit 1
  fi

  # Make sure the ssh key exists
  if [ ! -f "${SSH_PUBLIC_KEY_FILE}" ]
  then
    echo "SSH key not found. Please wait for the devcontainer to fully start."
    exit 1
  fi

  # Make sure the necessary commands exist
  for cmd in cloud-localds pkill qemu-img qemu-system-x86_64 sudo wget yq
  do
    if ! which "${cmd}" > /dev/null 2>&1
    then
      echo "Please install: ${cmd}"
      exit 1
    fi
  done

  # Download cloud image if not already present
  OS_IMAGE=${OS_IMAGE:-ubuntu-26.04}
  if [ "${OS_IMAGE}" = "centos9" ]
  then
    IMAGE_URL="${URL:-https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2}"
    IMAGE_FILE="${TEMP_DIR}/centos9.img"
    USE_UEFI=false
  elif [ "${OS_IMAGE}" = "centos10" ]
  then
    IMAGE_URL="${URL:-https://cloud.centos.org/centos/10-stream/x86_64/images/CentOS-Stream-GenericCloud-10-latest.x86_64.qcow2}"
    IMAGE_FILE="${TEMP_DIR}/centos10.img"
    USE_UEFI=false
  elif [ "${OS_IMAGE}" = "ubuntu-24.04" ]
  then
    IMAGE_URL="${URL:-https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img}"
    IMAGE_FILE="${TEMP_DIR}/ubuntu-24.04.img"
    USE_UEFI=true
  elif [ "${OS_IMAGE}" = "ubuntu-26.04" ]
  then
    IMAGE_URL="${URL:-https://cloud-images.ubuntu.com/resolute/current/resolute-server-cloudimg-amd64v3.img}"
    IMAGE_FILE="${TEMP_DIR}/ubuntu-26.04.img"
    USE_UEFI=true
  else
    echo "Unsupported os-image: ${OS_IMAGE}"
    exit 1
  fi
}

# SSH into a host and exits. Retries until successful.
# Host configuration should already be set up in your ~/.ssh/config file
#   wait_for_ssh <hostname|fqdn>
function wait_for_ssh() {
  local host=$1

  echo "Waiting on cloud-init to finish on ${host}..."
  while ! ssh "${host}" -o ConnectTimeout=1s -- 'sudo cloud-init status --wait' 2> /dev/null
  do
    sleep 2
    echo -n "."
  done
  echo "cloud-init has finished on ${host}"
}

if [[ "${CONFORMANCE}" = "true" ]]
then
  echo "Building environment for running conformance tests"

  PROXY_VM_CPU=2
  PROXY_VM_MEMORY=2
  CONTROL_PLANE_VM_CPU=4
  CONTROL_PLANE_VM_MEMORY=8
  WORKER_VM_CPU=4
  WORKER_VM_MEMORY=4
fi

[ -f ./.local/spin-up.env ] && echo "Sourcing ./.local/spin-up.env" && source ./.local/spin-up.env

get_options "$@"

# Create a directory to hold temporary files
mkdir -p "${TEMP_DIR}"

# Make sure other files exist
# shellcheck disable=SC2043
if [ ! -f "${OVMF_FILE}" ]
then
  echo "Please install: ovmf"
  exit 1
fi

if [ ! -f "${IMAGE_FILE}" ]
then
  echo "Downloading ${OS_IMAGE} cloud image..."
  wget "${IMAGE_URL}" -O "${IMAGE_FILE}"
fi

# Copy the UEFI file
[ "${USE_UEFI}" = "true" ] && cp "${OVMF_FILE}" "${TEMP_DIR}/"

# Stop any previous running virtual machines
pkill ssh -x || true
sudo pkill -f qemu-system-x86_64 || true

# Create the virtual machines
create_vm px  2021 11 ${PROXY_VM_CPU:-2} ${PROXY_VM_MEMORY:-2} 10 ",hostfwd=tcp::6443-:6443"
create_vm cp1 2022 12 ${CONTROL_PLANE_VM_CPU:-2} ${CONTROL_PLANE_VM_MEMORY:-4} 20
create_vm cp2 2023 13 ${CONTROL_PLANE_VM_CPU:-2} ${CONTROL_PLANE_VM_MEMORY:-4} 20
create_vm cp3 2024 14 ${CONTROL_PLANE_VM_CPU:-2} ${CONTROL_PLANE_VM_MEMORY:-4} 20
create_vm w1  2025 15 ${WORKER_VM_CPU:-2} ${WORKER_VM_MEMORY:-2} 20
create_vm w2  2026 16 ${WORKER_VM_CPU:-2} ${WORKER_VM_MEMORY:-2} 20

echo "Waiting for VMs to boot...this will take a few minutes."
echo "If it seems stuck, please check the ${TEMP_DIR}/<host>.stderr.log file for any errors."

wait_for_ssh "px.${DOMAIN}"
wait_for_ssh "cp1.${DOMAIN}"
wait_for_ssh "cp2.${DOMAIN}"
wait_for_ssh "cp3.${DOMAIN}"
wait_for_ssh "w1.${DOMAIN}"
wait_for_ssh "w2.${DOMAIN}"

echo "The VMs are up and running. You can SSH into them using the following command:"

echo "ssh px.${DOMAIN}"
echo "ssh cp1.${DOMAIN}"
echo "ssh cp2.${DOMAIN}"
echo "ssh cp3.${DOMAIN}"
echo "ssh w1.${DOMAIN}"
echo "ssh w2.${DOMAIN}"
