#!/bin/bash

set -e

RELEASE_JSON=$(curl -sL https://api.github.com/repos/vmware-tanzu/sonobuoy/releases/latest)
DOWNLOAD_URL=$(jq -r '.assets[] | select(.name | test(".*_linux_amd64.tar.gz$")) | .browser_download_url' <<< "$RELEASE_JSON")

echo "Downloading Sonobuoy from: ${DOWNLOAD_URL}"

mkdir -p /tmp/sonobuoy
cd /tmp/sonobuoy
curl -sL "$DOWNLOAD_URL" | tar xzv

./sonobuoy run certified-conformance --wait
RESULTS=$(./sonobuoy retrieve)
./sonobuoy delete --all --wait

mkdir -p /tmp/sonobuoy-results
cp "${RESULTS}" /tmp/sonobuoy-results/sonobuoy-results.tar.gz

./sonobuoy results "${RESULTS}" | tee /tmp/sonobuoy-results/sonobuoy-results.txt
