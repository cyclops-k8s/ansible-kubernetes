#!/bin/bash

# We don't do a set -e here because we want to capture the results even if the tests fail.

mkdir -p /tmp/hydrophone
cd /tmp/hydrophone

GOPATH=$(pwd)
export GOPATH

go install sigs.k8s.io/hydrophone@latest

bin/hydrophone --conformance -v 6 --parallel 10 --output-dir /tmp/results

tar -czvf /tmp/results.tar.gz -C /tmp/results .
mv /tmp/results.tar.gz /tmp/results/
