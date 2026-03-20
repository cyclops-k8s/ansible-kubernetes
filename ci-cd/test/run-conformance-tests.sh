#!/bin/bash

set -euo pipefail

RELEASE_JSON=$(curl -sL https://api.github.com/repos/vmware-tanzu/sonobuoy/releases/latest)
DOWNLOAD_URL=$(jq -r '.assets[] | select(.name | test(".*_linux_amd64.tar.gz$")) | .browser_download_url' <<< "$RELEASE_JSON")

if [ -z "$DOWNLOAD_URL" ]
then
  echo "ERROR: Failed to find Sonobuoy download URL in release assets"
  exit 1
fi

echo "Downloading Sonobuoy from: ${DOWNLOAD_URL}"

mkdir -p /tmp/sonobuoy
cd /tmp/sonobuoy
curl -sL "$DOWNLOAD_URL" | tar xzv

SONOBUOY_TIMEOUT_SECONDS="${SONOBUOY_TIMEOUT_SECONDS:-7200}"
if ! timeout "${SONOBUOY_TIMEOUT_SECONDS}" ./sonobuoy run --mode=certified-conformance --wait
then
  echo "ERROR: Sonobuoy run did not complete within ${SONOBUOY_TIMEOUT_SECONDS} seconds or failed"
  ./sonobuoy status || true
  exit 1
fi
RESULTS=$(./sonobuoy retrieve)
./sonobuoy delete --all --wait
./sonobuoy results "${RESULTS}" | tee sonobuoy-results.txt
