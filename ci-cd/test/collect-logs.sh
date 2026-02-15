#!/bin/bash

GITHUB_RUN_NUMBER=${GITHUB_RUN_NUMBER:-"local"}
LOG_ROOT="/tmp/logs/${GITHUB_RUN_NUMBER}"

mkdir -p "$LOG_ROOT"

cd tofu || exit 1
TOFU_OUTPUT=$(tofu output -json) || true
echo "${TOFU_OUTPUT}" > "${LOG_ROOT}/tofu-output.json" 2>&1 || true

if [ -n "${TOFU_OUTPUT}" ]; then
ALL_HOSTS=$(echo "${TOFU_OUTPUT}" | jq -r '.information.value | (.proxy.hostname, .control_planes[].hostname, .workers[].hostname)' 2>/dev/null)

for host in ${ALL_HOSTS}; do
  echo "Collecting logs from ${host}..."
  ssh "ansible@${host}.cyclops-vms" -i "${HOME}/.ssh/gh-${GITHUB_RUN_NUMBER}.pem" "sudo journalctl -u kubelet -n 1000" > "${LOG_ROOT}/${host}-kubelet.log" 2>&1 || true
  ssh "ansible@${host}.cyclops-vms" -i "${HOME}/.ssh/gh-${GITHUB_RUN_NUMBER}.pem" "sudo journalctl -u containerd -n 500" > "${LOG_ROOT}/${host}-containerd.log" 2>&1 || true
  ssh "ansible@${host}.cyclops-vms" -i "${HOME}/.ssh/gh-${GITHUB_RUN_NUMBER}.pem" "sudo kubeadm version" > "${LOG_ROOT}/${host}-kubeadm-version.log" 2>&1 || true
  ssh "ansible@${host}.cyclops-vms" -i "${HOME}/.ssh/gh-${GITHUB_RUN_NUMBER}.pem" "sudo tar -cv /var/log" > "${LOG_ROOT}/${host}-log.tar" 2>/dev/null || true
done
fi

kubectl get all -A > "${LOG_ROOT}/kubectl-get-all.log" 2>&1 || true
kubectl get nodes -o wide > "${LOG_ROOT}/kubectl-nodes.log" 2>&1 || true
kubectl get events -A --sort-by='.lastTimestamp' > "${LOG_ROOT}/kubectl-events.log" 2>&1 || true
kubectl version --output=yaml > "${LOG_ROOT}/kubectl-version.log" 2>&1 || true
