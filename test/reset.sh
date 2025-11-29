#!/bin/bash

if ! ps -ef | grep qemu-system-x86_64 | grep -v grep
then
  echo "VMs are not running, please run spin-up-vms.sh first."
  exit 1
fi

echo "VM's are running."

ansible-playbook -i inventory.yaml -i vars.yaml ../reset.yml
