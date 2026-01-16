#!/usr/bin/bash -e

cd tofu
tofu destroy \
  -auto-approve \
  -var="image_url=${IMAGE_URL}" \
  -var="hostname_prefix=${GITHUB_RUN_NUMBER:-testvms}" \
