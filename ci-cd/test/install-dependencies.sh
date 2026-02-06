#!/bin/bash

# Update package list
sudo apt-get update

# Install pipx for Ansible installation
sudo apt-get install -y pipx python3-pip python3-venv

# Install Ansible using pipx
pipx install --include-deps ansible
pipx ensurepath

# Inject dnspython into Ansible virtual environment
pipx inject ansible dnspython

# Install Ansible collections from requirements.yaml
ansible-galaxy collection install -r ../../requirements.yaml

# Install OpenTofu
if ! command -v tofu &> /dev/null; then
  echo "Installing OpenTofu..."
  curl --proto '=https' --tlsv1.2 -fsSL https://get.opentofu.org/install-opentofu.sh > /tmp/install-opentofu.sh
  sudo bash /tmp/install-opentofu.sh --install-method deb
fi

# Install kubectl
if ! command -v kubectl &> /dev/null; then
  echo "Installing kubectl..."
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
  rm kubectl
fi

sudo apt-get install -y jq yq

echo "Verifying installations and versions..."
ansible --version
tofu --version
kubectl version --client
jq --version
