#!/bin/bash

if ! pgrep -f "^qemu"
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
