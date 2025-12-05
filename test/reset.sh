#!/usr/bin/bash -e

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

echo "Running the ansible playbook to reset kubernetes"
ansible-playbook -i "inventory_${CMD}.yaml" -i vars.yaml ../reset.yaml
