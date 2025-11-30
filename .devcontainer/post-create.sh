#!/bin/bash
set -e

pipx install ansible-core
pipx inject ansible-core dnspython
pipx inject --include-apps ansible-core ansible-dev-tools ansible-lint
ansible-galaxy collection install -r requirements.yml

sudo apt update
sudo apt install -y bind9-dnsutils git iputils-ping sshpass vim yq wget curl man # Basic dev tools
sudo apt install -y \
    qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils cpu-checker \
    network-manager linux-headers-generic \
    uml-utilities virt-manager git \
    wget libguestfs-tools p7zip-full make dmg2img tesseract-ocr \
    tesseract-ocr-eng genisoimage vim net-tools screen firewalld libncurses-dev \
    libgirepository-2.0-dev cloud-utils kubectx # Testing environment tools

echo -n 'password' > ~/.password

mkdir -p ~/.ssh
cp -r /host/.ssh/* ~/.ssh/

ssh-keygen -t rsa -b 4096 -f ~/.rsa_key -N ""

cat <<EOF >> ~/.ssh/config
Host *
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null

Host px.k8s.local
    HostName localhost
    Port 2021
    User ansible
    IdentityFile ~/.rsa_key

Host cp1.k8s.local
    HostName localhost
    Port 2022
    User ansible
    IdentityFile ~/.rsa_key

Host cp2.k8s.local
    HostName localhost
    Port 2023
    User ansible
    IdentityFile ~/.rsa_key

Host cp3.k8s.local
    HostName localhost
    Port 2024
    User ansible
    IdentityFile ~/.rsa_key

Host w1.k8s.local
    HostName localhost
    Port 2025
    User ansible
    IdentityFile ~/.rsa_key

Host w2.k8s.local
    HostName localhost
    Port 2026
    User ansible
    IdentityFile ~/.rsa_key
EOF

sudo usermod -aG kvm codespace
sudo usermod -aG libvirt codespace

cat <<EOF > ~/.vimrc
filetype indent on
filetype plugin on

set background=dark
set cul
set ignorecase
set incsearch
set laststatus=2
set modeline
set mouse=a
set number
set paste
set ruler
set scrolloff=5
set showmatch
set title

if &t_Co > 2 || has("gui_running")
  syntax on
  set hlsearch
endif
EOF

echo "127.0.0.1 cp.k8s.local" | sudo tee -a /etc/hosts
