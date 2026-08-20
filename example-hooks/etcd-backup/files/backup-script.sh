#!/bin/bash
set -euo pipefail

BACKUP_PATH=${BACKUP_PATH:-/var/lib/etcd/snapshots}
CRICTL_PATH=${CRICTL_PATH:-/usr/bin/crictl}
SOURCE_PATH=${SOURCE_PATH:-/var/lib/etcd/snapshots}
CONTAINERD_SOCKET=${CONTAINERD_SOCKET:-unix:///run/containerd/containerd.sock}
TARGET_PATH=${TARGET_PATH:-}
RETENTION_DAYS=${RETENTION_DAYS:-7}
AMOUNT_TO_KEEP=${AMOUNT_TO_KEEP:-5}
POST_EXECUTE_SCRIPT=${POST_EXECUTE_SCRIPT:-}

echo "Backup path: ${BACKUP_PATH}"
echo "Crictl path: ${CRICTL_PATH}"
echo "Source path: ${SOURCE_PATH}"
echo "Containerd socket: ${CONTAINERD_SOCKET}"
echo "Target path: ${TARGET_PATH}"
echo "Retention days: ${RETENTION_DAYS}"
echo "Amount to keep: ${AMOUNT_TO_KEEP}"
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

SNAPSHOT_FILENAME="snap-$(date +%Y%m%d-%H%M%S).db"
SNAPSHOT_SOURCE_PATH="${SOURCE_PATH}/${SNAPSHOT_FILENAME}"
SNAPSHOT_PATH="${TARGET_PATH}/${SNAPSHOT_FILENAME}"

echo "Snapshot filename: ${SNAPSHOT_FILENAME}"
echo "Snapshot source path: ${SNAPSHOT_SOURCE_PATH}"
echo "Snapshot path: ${SNAPSHOT_PATH}"

export SNAPSHOT_FILENAME
export SNAPSHOT_PATH

${CRICTL_PATH} \
  --runtime-endpoint "${CONTAINERD_SOCKET}" \
  exec "${ID}" \
  etcdctl snapshot save "${BACKUP_PATH}/${SNAPSHOT_FILENAME}" --cert /etc/kubernetes/pki/etcd/peer.crt --key /etc/kubernetes/pki/etcd/peer.key --endpoints https://127.0.0.1:2379 --cacert /etc/kubernetes/pki/etcd/ca.crt

if [[ -n "${TARGET_PATH}" ]]
then
  if [[ ! -d "${TARGET_PATH}" && "${TARGET_PATH}" != "/" && "${TARGET_PATH}" ]]
  then
    echo "TARGET_PATH ${TARGET_PATH} must exist, not be /"
    exit 1
  fi
  echo "Moving backup to ${TARGET_PATH}"

  mv "${SNAPSHOT_SOURCE_PATH}" "${TARGET_PATH}"

  if [[ "${RETENTION_DAYS}" =~ ^[0-9]+$ ]] && [[ "${RETENTION_DAYS}" -gt 0 ]]
  then
    echo "Removing files older than ${RETENTION_DAYS} days"
    find "${TARGET_PATH}" -type f -mtime +"${RETENTION_DAYS}" -delete
  fi

  if [[ "${AMOUNT_TO_KEEP}" =~ ^[0-9]+$ ]] && [[ "${AMOUNT_TO_KEEP}" -gt 0 ]]
  then
    echo "Keeping only the latest ${AMOUNT_TO_KEEP} files"
    for snapshot in $(find "${TARGET_PATH}" -maxdepth 1 -type f -printf '%T@ %p\n' | sort -nr | tail -n +"$((AMOUNT_TO_KEEP + 1))" | cut -d' ' -f2-)
    do
      echo "Removing snapshot ${snapshot}"
      rm "${snapshot}"
    done
  fi
fi

if [[ -n "${POST_EXECUTE_SCRIPT}" ]]
then
  echo "Executing post-execute script ${POST_EXECUTE_SCRIPT}"
  "${POST_EXECUTE_SCRIPT}"
fi
