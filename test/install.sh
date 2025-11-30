#!/bin/bash

if [ -z "$DEVCONTAINER" ]
then
    echo "This script is intended to only be run inside a devcontainer."
    exit 1
fi

if ! pgrep -f "^qemu-system-x86_64" > /dev/null
then
  echo "VMs are not running, please run spin-up-test-environment.sh first."
  exit 1
fi

echo "VMs are running."

echo "Running Terraform to generate inventory and configuration"
terraform init
terraform apply -auto-approve
if [ $? -ne 0 ]; then
  echo "Terraform apply failed"
  exit 1
fi

ansible-playbook -i inventory.yaml -i vars.yaml ../install.yml
