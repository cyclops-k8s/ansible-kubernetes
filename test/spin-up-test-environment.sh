#!/usr/bin/bash -e

SSH_PUBLIC_KEY_FILE=${SSH_PUBLIC_KEY_FILE:-~/.ssh/devcontainer.id_rsa.pub}
TEMP_DIR=${TEMP_DIR:-.temp}
DOMAIN=${DOMAIN:-k8s.local}
IP_PREFIX=${IP_PREFIX:-10.255.254}

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

# Make sure other files exist
# shellcheck disable=SC2043
for f in OVMF=/usr/share/OVMF/OVMF_CODE_4M.fd
do
  if [ ! -f "${f/*=/}" ]
  then
    echo "Please install: ${f/=*/}"
    exit 1
  fi
done

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
  cat cloud-init/user-data | yq --yaml-output ".hostname = \"${name}\" | .fqdn = \"${name}.${DOMAIN}\" | .users[0].ssh_authorized_keys = [\"${SSH_PUBLIC_KEY}\"]" >> "${TEMP_DIR}/${name}.user-data"
  cat cloud-init/network | yq --yaml-output ".network.ethernets.enp0s3.addresses += [\"${IP_PREFIX}.${ip}/24\"] | .network.ethernets.enp0s2.nameservers.search = [ \"${DOMAIN}\" ]" >> "${TEMP_DIR}/${name}.network"

  # Create the cloud-init iso
  cloud-localds "${TEMP_DIR}/${name}.cloud-init.iso" "${TEMP_DIR}/${name}.user-data" -N "${TEMP_DIR}/${name}.network" > /dev/null

  # Create the virtual machine hard drive
  echo "Creating VM ${name} on port ${ssh_port}..."
  qemu-img create -b ubuntu.img -F qcow2 -f qcow2 "${TEMP_DIR}/${name}.img" "${hdd_size}G"

  # Each VM needs its own UEFI vars file
  cp /usr/share/OVMF/OVMF_VARS_4M.fd "${TEMP_DIR}/${name}.ovmf_vars_4m.fd"

  # Qemu needs permissons to write to the drive files
  chmod o+w "${TEMP_DIR}/${name}.img"
  chmod o+w "${TEMP_DIR}/${name}.ovmf_vars_4m.fd"

  # Create/start the virtual machine
  sudo -b qemu-system-x86_64 \
      -boot menu=off \
      -cdrom "${TEMP_DIR}/${name}.cloud-init.iso" \
      -cpu host \
      -drive if=pflash,format=raw,readonly=on,file="${TEMP_DIR}/OVMF_CODE_4M.fd" \
      -drive if=pflash,format=raw,file="${TEMP_DIR}/${name}.ovmf_vars_4m.fd" \
      -drive file="${TEMP_DIR}/${name}.img" \
      -enable-kvm \
      -device virtio-net-pci,netdev=net0,mac="52:54:00:00:00:${ip}" \
      -device virtio-net-pci,netdev=net1,mac="52:54:00:00:01:${ip}" \
      -m "${mem_size}G" \
      -machine accel=kvm,type=q35 \
      -nographic \
      -netdev user,id=net0,hostfwd="tcp::${ssh_port}-:22${additional_forwarding}" \
      -netdev socket,id=net1,mcast=230.0.0.1:1234 \
      -smbios type=0,uefi=on \
      -smp "${cpu_num}" 1>"${TEMP_DIR}/${name}.stdout.log" 2>"${TEMP_DIR}/${name}.stderr.log"

  # Allow the virtual machine some time to boot
  sleep 3
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
}

# Create a directory to hold temporary files
mkdir -p "${TEMP_DIR}"

# Download ubuntu cloud image questing if not already present
if [ ! -f "${TEMP_DIR}/ubuntu.img" ]
then
  wget https://cloud-images.ubuntu.com/questing/current/questing-server-cloudimg-amd64.img -O "${TEMP_DIR}/ubuntu.img"
fi

# Copy the UEFI file
cp /usr/share/OVMF/OVMF_CODE_4M.fd "${TEMP_DIR}/"

# Stop any previous running virtual machines
pkill ssh -x || true
sudo pkill -f qemu-system-x86_64 || true

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
