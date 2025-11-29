#!/bin/bash -e

PUB_KEY=$(cat ~/.rsa_key.pub)
gateway=$(ip r | grep default | awk '{print $3}')

function create_vm() {
    local name=$1
    local port=$2
    local ip=$3
    local addional_forwarding=$4

    echo "#cloud-config" > .temp/user-data
    echo "" >> .temp/user-data
    echo "#cloud-config" > .temp/network
    echo "" >> .temp/network

    cat cloud-init/user-data | yq ".hostname = \"${name}\" | .fqdn = \"${name}.k8s.local\" | .users[0].ssh_authorized_keys = [\"${PUB_KEY}\"]" --yaml-output >> .temp/user-data
    cat cloud-init/network | yq --yaml-output ".network.ethernets.ens4.addresses += [\"10.255.254.${ip}/24\"]" >> .temp/network

    cloud-localds .temp/cloud-init-${name}.iso .temp/user-data -N .temp/network > /dev/null

    echo "Creating VM $name on port $port..."
    [ -f .temp/${name}.img ] && rm .temp/${name}.img
    qemu-img create -b ubuntu.img -F qcow2 -f qcow2 .temp/${name}.img 20G

    sudo qemu-system-x86_64 \
        -enable-kvm \
        -cpu host \
        -boot menu=off \
        -drive if=pflash,format=raw,readonly=on,file=.temp/OVMF_CODE_4M.fd \
        -drive if=pflash,format=raw,file=.temp/OVMF_VARS_4M.fd \
        -drive file=.temp/${name}.img \
        -cdrom .temp/cloud-init-${name}.iso \
        -device virtio-net-pci,netdev=net0,mac=52:54:00:00:00:${ip} \
        -device virtio-net-pci,netdev=net1,mac=52:54:00:00:01:${ip} \
        -netdev user,id=net0,hostfwd=tcp::${port}-:22${addional_forwarding} \
        -netdev socket,id=net1,mcast=230.0.0.1:1234 \
        -m 4G \
        -smp 2 \
        -nographic \
        -smbios type=0,uefi=on 1>.temp/${name}.stdout.log 2>.temp/${name}.stderr.log &
}

function wait_for_ssh() {
  local host=$1
  local port=$2
  echo "Waiting for SSH on $host:$port..."
  while ! ssh ansible@localhost -p $port -i ~/.rsa_key -o ConnectTimeout=1s -o StrictHostKeyChecking=no -- exit 0 2>/dev/null; do
    sleep 2
    echo -n "."
  done
  echo "SSH is available on $host:$port"
}

# download ubuntu cloud image questing if not already present
if [ ! -f .temp/ubuntu.img ]; then
    wget https://cloud-images.ubuntu.com/questing/current/questing-server-cloudimg-amd64.img -O .temp/ubuntu.img
fi

cp /usr/share/OVMF/* .temp

[ -f ~/.ssh/known_hosts ] && rm ~/.ssh/known_hosts
pkill ssh || true
sudo pkill qemu || true

create_vm "px" 2021 11 ",hostfwd=tcp::6443-:6443"
create_vm "cp1" 2022 12
create_vm "cp2" 2023 13
create_vm "cp3" 2024 14
create_vm "w1" 2025 15
create_vm "w2" 2026 16

echo "Waiting for VMs to boot...this will take a few minutes."
echo "If it seems stuck, please check the .temp/px.stderr.log file for any errors."

wait_for_ssh "localhost" 2021
wait_for_ssh "localhost" 2022
wait_for_ssh "localhost" 2023
wait_for_ssh "localhost" 2024
wait_for_ssh "localhost" 2025
wait_for_ssh "localhost" 2026

echo "The VMs are up and running. You can SSH into them using the following command:"

echo "ssh px.k8s.local"
echo "ssh cp1.k8s.local"
echo "ssh cp2.k8s.local"
echo "ssh cp3.k8s.local"
echo "ssh w1.k8s.local"
echo "ssh w2.k8s.local"

