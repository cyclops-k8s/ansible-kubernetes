#!/bin/bash

CONTAINERS=$(docker ps --format '{{.Names}}' | grep k8s- || true)

EXPECTED_CONTAINERS=(
  "k8s-px"
  "k8s-cp1"
  "k8s-cp2"
  "k8s-cp3"
  "k8s-w1"
  "k8s-w2"
)

for expected in "${EXPECTED_CONTAINERS[@]}"; do
  if ! echo "$CONTAINERS" | grep -q "^${expected}$"; then
    echo "Container ${expected} is not running, please run spin-up-vms.sh first."
    exit 1
  fi
done

echo "Containers are running."

echo "Running Terraform to generate inventory and configuration"
terraform init
terraform apply -auto-approve
if [ $? -ne 0 ]; then
  echo "Terraform apply failed"
  exit 1
fi