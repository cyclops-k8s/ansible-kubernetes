#!/usr/bin/bash -e

usage()
{
  echo "Usage: $0 [options] -- tfvar files
  -d | --domain               The domain to use for the VMs.
                              Default is k8s.local
                              Environment Variable: DOMAIN
  -o | --os-image             The OS image to use for the VMs. Supported values are 'ubuntu-25.10', 'ubuntu-24.04', and 'centos'.
                              Default is 'ubuntu-25.10'.
                              Valid values are:
                                centos
                                ubuntu-25.10
                                ubuntu-24.04
                              Environment Variable: OS_IMAGE
  -v | --ovmf-file            The OVMF file to use for UEFI booting.
                              Default is /usr/share/OVMF/OVMF_CODE_4M.fd
                              Environment Variable: OVMF_FILE
  -p | --ip-prefix            The IP prefix to use for the VMs.
                              Default is 10.255.254
                              Environment Variable: IP_PREFIX
  -s | --ssh-key-file         The SSH private key file to use for VM access.
                              Default is ~/.ssh/devcontainer.id_rsa
                              Environment Variable: SSH_KEY_FILE
  -S | --ssh-public-key-file  The SSH public key file to use for VM access.
                              Default is ~/.ssh/devcontainer.id_rsa.pub
                              Environment Variable: SSH_PUBLIC_KEY_FILE
  -t | --temp-dir             The temporary directory to store VM files.
                              Default is ./.temp
                              Environment Variable: TEMP_DIR
  -u | --url                  The URL to download the OS image from.
                              Default is the official cloud image URLs.
                              Environment Variable: URL
  -h | --help                 Shows this helpful usage statement.

Examples:
  # Use default values
  $0

  # Specify all options
  $0 -d somethingrandom.tld \\
    -o centos \\
    -p 10.251.251 \\
    -s ~/.ssh/k8s.id \\
    -S ~/.ssh/k8s.id.pub \\
    -t /tmp/k8s-vms \\
    -u https://example.com/custom-centos-image.qcow2 \\
    -v ~/ovmf.fd \\
    -- \\
    ../example-hooks/registry-mirrors/post_proxies/test.tfvars

  # Using Environment Variables:
    export DOMAIN=somethingrandom.tld \\
    export OS_IMAGE=centos \\
    export IP_PREFIX=10.251.251 \\
    export SSH_KEY_FILE=~/.ssh/k8s.id \\
    export SSH_PUBLIC_KEY_FILE=~/.ssh/k8s.id.pub \\
    export TEMP_DIR=/tmp/k8s-vms \\
    export URL=https://example.com/custom-centos-image.qcow2 \\
    export OVMF_FILE=~/ovmf.fd \\
    $0 \\
    -- \\
    ../example-hooks/registry-mirrors/post_proxies/test.tfvars
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
  local name=$1
  local ssh_port=$2
  local ip=$3
  local cpu_num=$4
  local mem_size=$5
  local hdd_size=$6
  local additional_forwarding=$7

  echo "Creating virtual machine: ${name}"
  echo "  SSH Port: ${ssh_port}"
  echo "  IP: ${ip}"
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

  # Update cloud-init files
  SSH_PUBLIC_KEY=$(cat "${SSH_PUBLIC_KEY_FILE}")
  cat cloud-init/user-data | \
    yq --yaml-output \
      ".hostname = \"${name}\" | \
       .fqdn = \"${name}.${DOMAIN}\" | \
       .users[0].ssh_authorized_keys = [\"${SSH_PUBLIC_KEY}\"]" \
    >> "${TEMP_DIR}/${name}.user-data"

  # Set MAC addresses and IP configuration in network config
  MAC0="52:54:00:00:00:${ip}"
  MAC1="52:54:00:00:01:${ip}"
  cat cloud-init/network | \
    yq --yaml-output \
      ".network.ethernets.eth0.match.macaddress = \"${MAC0}\" | \
       .network.ethernets.eth0.nameservers.search = [ \"${DOMAIN}\" ] | \
       .network.ethernets.eth1.match.macaddress = \"${MAC1}\" | \
       .network.ethernets.eth1.addresses += [\"${IP_PREFIX}.${ip}/24\"]" \
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
  # Build QEMU command based on boot type

  if [ "${USE_UEFI}" = true ]
  then
    # UEFI boot (Ubuntu)
    QEMU_BOOT_ARGS="-drive if=pflash,format=raw,readonly=on,file=${TEMP_DIR}/OVMF_CODE_4M.fd -drive if=pflash,format=raw,file=${TEMP_DIR}/${name}.ovmf_vars_4m.fd -smbios type=0,uefi=on"
    cp /usr/share/OVMF/OVMF_VARS_4M.fd "${TEMP_DIR}/${name}.ovmf_vars_4m.fd"
    # Qemu needs permissions to write to the UEFI vars file
    chmod o+w "${TEMP_DIR}/${name}.ovmf_vars_4m.fd"
  fi

  # shellcheck disable=SC2086
  # Create/start the virtual machine
  sudo -b qemu-system-x86_64 \
      -boot menu=off \
      -cdrom "${TEMP_DIR}/${name}.cloud-init.iso" \
      -cpu host \
      ${QEMU_BOOT_ARGS} \
      -drive file="${TEMP_DIR}/${name}.img" \
      -enable-kvm \
      -device virtio-net-pci,netdev=net0,mac="${MAC0}" \
      -device virtio-net-pci,netdev=net1,mac="${MAC1}" \
      -m "${mem_size}G" \
      -machine accel=kvm,type=q35 \
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
                     -o o:s:S:t:d:p:u:v:h \
                     --long os-image:,ssh-key-file:,ssh-public-key-file:,temp-dir:,domain:,ip-prefix:,url:,ovmf-file:,help \
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
      -d | --domain)       export DOMAIN="$2"; shift 2 ;;
      -p | --ip-prefix)    export IP_PREFIX="$2"; shift 2 ;;
      -o | --os-image)     export OS_IMAGE="$2"; shift 2 ;;
      -s | --ssh-key-file) export SSH_KEY_FILE="$2"; shift 2 ;;
      -S | --ssh-public-key-file) export SSH_PUBLIC_KEY_FILE="$2"; shift 2 ;;
      -t | --temp-dir)     export TEMP_DIR="$2"; shift 2 ;;
      -u | --url)          export URL="$2"; shift 2 ;;
      -v | --ovmf-file)    export OVMF_FILE="$2"; shift 2 ;;
      -h | --help)         usage;;
      --)                  shift; break ;;
      *)                   echo "Unexpected option: $1"; usage ;;
    esac
  done

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
  OS_IMAGE=${OS_IMAGE:-ubuntu-24.04}
  if [ "${OS_IMAGE}" = "centos" ]
  then
    IMAGE_URL="${URL:-https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2}"
    IMAGE_FILE="${TEMP_DIR}/centos.img"
    USE_UEFI=false
  elif [ "${OS_IMAGE}" = "ubuntu-24.04" ]
  then
    IMAGE_URL="${URL:-https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img}"
    IMAGE_FILE="${TEMP_DIR}/ubuntu-24.04.img"
    USE_UEFI=true
  elif [ "${OS_IMAGE}" = "ubuntu-25.10" ]
  then
    IMAGE_URL="${URL:-https://cloud-images.ubuntu.com/questing/current/questing-server-cloudimg-amd64.img}"
    IMAGE_FILE="${TEMP_DIR}/ubuntu-25.10.img"
    USE_UEFI=true
  else
    echo "Unsupported os-image: ${OS_IMAGE}"
    exit 1
  fi
}

# SSH into a host and exits. Retries until successfull.
# Host configuration should already be set up in your ~/.ssh/config file
#   wait_for_ssh <hostname|fqdn>
function wait_for_ssh() {
  local host=$1

  echo "Waiting for SSH on ${host}..."
  while ! ssh "${host}" -o ConnectTimeout=1s -- exit 0 2> /dev/null
  do
    sleep 2
    echo -n "."
  done
  echo "SSH is available on ${host}"

  echo "Waiting on cloud-init to finish on ${host}..."
  while ! ssh "${host}" 'sudo cloud-init status --wait' 2> /dev/null
  do
    sleep 2
    echo -n "."
  done
  echo "cloud-init has finished on ${host}"
}

get_options "$@"

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

# Create a directory to hold temporary files
mkdir -p "${TEMP_DIR}"

# Copy the UEFI file
cp "${OVMF_FILE}" "${TEMP_DIR}/"

# Stop any previous running virtual machines
pkill ssh -x || true
sudo pkill -f qemu-system-x86_64 || true

# Create the virtual machines
create_vm px  2021 11 2 2 10 ",hostfwd=tcp::6443-:6443"
create_vm cp1 2022 12 2 4 20
create_vm cp2 2023 13 2 4 20
create_vm cp3 2024 14 2 4 20
create_vm w1  2025 15 2 4 20
create_vm w2  2026 16 2 4 20

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
