#!/bin/bash

if ! pgrep -f "^qemu-system-x86_64" > /dev/null
then
  echo "VMs are not running, please run spin-up-vms.sh first."
  exit 1
fi

echo "VMs are running."

ansible-playbook -i inventory.yaml -i vars.yaml ../reset.yml
