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

ansible-playbook -i inventory.yaml -i vars.yaml ../reset.yml
