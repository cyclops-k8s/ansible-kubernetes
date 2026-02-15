#!/bin/bash

set -e

# Create a test deployment
kubectl create namespace smoke-test
kubectl -n smoke-test create deployment nginx --image=quay.io/prometheus/busybox:latest --replicas=2 -- sh -c "while true; do sleep 3600; done"
kubectl -n smoke-test rollout status deployment/nginx --timeout=300s

# Verify deployment
READY_REPLICAS=$(kubectl -n smoke-test get deployment nginx -o jsonpath='{.status.readyReplicas}')
if [ "${READY_REPLICAS}" != "2" ]
then
  echo "ERROR: Expected 2 ready replicas, found ${READY_REPLICAS}"
  kubectl -n smoke-test describe deployment nginx
  exit 1
fi

# Clean up test deployment
kubectl -n smoke-test delete deployment nginx

echo "Smoke tests passed!"

kubectl delete namespace smoke-test
