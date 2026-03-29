#!/bin/bash

# We don't do a set -e here because we want to capture the results even if the tests fail.

mkdir -p /tmp/hydrophone
mkdir -p /tmp/results

cd /tmp/hydrophone

GOPATH=$(pwd)
export GOPATH

go install sigs.k8s.io/hydrophone@latest
EXIT_CODE=$?
if [ "$EXIT_CODE" -ne 0 ]; then
  echo "Failed to install hydrophone"
  exit "$EXIT_CODE"
else
  echo "Successfully installed hydrophone"
  bin/hydrophone --conformance -v 6 --parallel 10 --output-dir /tmp/results
  EXIT_CODE=$?
fi

tar -czvf /tmp/results.tar.gz -C /tmp/results .
mv /tmp/results.tar.gz /tmp/results/

exit "$EXIT_CODE"
