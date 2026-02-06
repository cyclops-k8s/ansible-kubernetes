#!/bin/bash

GITHUB_RUN_NUMBER=${GITHUB_RUN_NUMBER:-"local"}

mkdir -p "/tmp/upgrade-logs-${GITHUB_RUN_NUMBER}"

cd tofu || exit 1
TOFU_OUTPUT=$(tofu output -json) || true
echo "${TOFU_OUTPUT}" > "/tmp/upgrade-logs-${GITHUB_RUN_NUMBER}/tofu-output.json" 2>&1 || true
if [ -n "${TOFU_OUTPUT}" ]; then
ALL_HOSTS=$(echo "${TOFU_OUTPUT}" | jq -r '.information.value | (.proxy.hostname, .control_planes[].hostname, .workers[].hostname)' 2>/dev/null)

for host in ${ALL_HOSTS}; do
    echo "Collecting logs from ${host}..."
    ssh "ansible@${host}.cyclops-vms" -i "${HOME}/.ssh/gh-${GITHUB_RUN_NUMBER}.pem" "sudo journalctl -u kubelet -n 1000" > "/tmp/upgrade-logs-${GITHUB_RUN_NUMBER}/${host}-kubelet.log" 2>&1 || true
    ssh "ansible@${host}.cyclops-vms" -i "${HOME}/.ssh/gh-${GITHUB_RUN_NUMBER}.pem" "sudo journalctl -u containerd -n 500" > "/tmp/upgrade-logs-${GITHUB_RUN_NUMBER}/${host}-containerd.log" 2>&1 || true
    ssh "ansible@${host}.cyclops-vms" -i "${HOME}/.ssh/gh-${GITHUB_RUN_NUMBER}.pem" "sudo kubeadm version" > "/tmp/upgrade-logs-${GITHUB_RUN_NUMBER}/${host}-kubeadm-version.log" 2>&1 || true
    ssh "ansible@${host}.cyclops-vms" -i "${HOME}/.ssh/gh-${GITHUB_RUN_NUMBER}.pem" "sudo tar -cv /var/log" > "/tmp/upgrade-logs-${GITHUB_RUN_NUMBER}/${host}-log.tar" 2>/dev/null || true
done
fi

kubectl get all -A > "/tmp/upgrade-logs-${GITHUB_RUN_NUMBER}/kubectl-get-all.log" 2>&1 || true
kubectl get nodes -o wide > "/tmp/upgrade-logs-${GITHUB_RUN_NUMBER}/kubectl-nodes.log" 2>&1 || true
kubectl get events -A --sort-by='.lastTimestamp' > "/tmp/upgrade-logs-${GITHUB_RUN_NUMBER}/kubectl-events.log" 2>&1 || true
kubectl version --output=yaml > "/tmp/upgrade-logs-${GITHUB_RUN_NUMBER}/kubectl-version.log" 2>&1 || true

