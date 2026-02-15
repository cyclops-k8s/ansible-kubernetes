#!/bin/bash

set -e

KUBERNETES_VERSION=$1

# Wait for all nodes to be ready
echo "Waiting for all nodes to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=600s

# Verify node count
ACTUAL_NODES=$(kubectl get nodes --no-headers | wc -l)

if [ "${ACTUAL_NODES}" -lt 6 ]
then
  echo "ERROR: Expected at least 6 nodes, found ${ACTUAL_NODES}"
  kubectl get nodes
  exit 1
fi

# Verify all system pods are running
echo "Checking system pods..."
kubectl get pods -A

# Check for any pods in error state
ERROR_PODS=$(kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded --no-headers 2>/dev/null | wc -l)
if [ "${ERROR_PODS}" -gt 0 ]
then
  echo "WARNING: Found ${ERROR_PODS} pods not in Running/Succeeded state"
  kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded
fi

# Check cluster version
VERSION=$(kubectl version --output yaml)
echo "${VERSION}"
NODES=$(kubectl get nodes -o yaml)

if [ \
    "$(
      echo "$NODES" | \
      yq "
        (
          .items |
            map(
              select(
                .status.nodeInfo.kubeletVersion |
                startswith(\"v${KUBERNETES_VERSION}\") |
                not
              )
            ) |
            length != 0
        )"
    )" == 'true' \
  ]
then
  echo "ERROR: Not all nodes installed with version ${KUBERNETES_VERSION}"
  exit 1
fi

echo "Cluster verification complete!"
