#!/bin/bash
set -euo pipefail

CRICTL_PATH=${CRICTL_PATH:-/usr/bin/crictl}
CONTAINERD_SOCKET=${CONTAINERD_SOCKET:-unix:///run/containerd/containerd.sock}
POST_EXECUTE_SCRIPT=${POST_EXECUTE_SCRIPT:-}

echo "Crictl path: ${CRICTL_PATH}"
echo "Containerd socket: ${CONTAINERD_SOCKET}"
echo "Post execute script: ${POST_EXECUTE_SCRIPT}"

POD_ID=$(${CRICTL_PATH} \
  --runtime-endpoint "${CONTAINERD_SOCKET}" \
  pods \
  --namespace kube-system \
  --label=component=etcd \
  --label=tier=control-plane \
  -o json \
  | jq '.items[].id' -r)
echo "Pod id: ${POD_ID}"

ID=$(${CRICTL_PATH} \
  --runtime-endpoint "${CONTAINERD_SOCKET}" \
  ps \
  --namespace kube-system \
  --name etcd \
  --pod "${POD_ID}" \
  -o json \
  | jq '.containers[].id' -r)
echo "Container id: ${ID}"

${CRICTL_PATH} \
  --runtime-endpoint "${CONTAINERD_SOCKET}" \
  exec "${ID}" \
  etcdctl defrag --cluster --cert /etc/kubernetes/pki/etcd/peer.crt --key /etc/kubernetes/pki/etcd/peer.key --endpoints https://127.0.0.1:2379 --cacert /etc/kubernetes/pki/etcd/ca.crt

if [[ -n "${POST_EXECUTE_SCRIPT}" ]]
then
  echo "Executing post-execute script ${POST_EXECUTE_SCRIPT}"
  "${POST_EXECUTE_SCRIPT}"
fi
