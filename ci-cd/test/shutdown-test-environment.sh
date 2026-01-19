#!/usr/bin/bash -e

cd tofu
tofu destroy \
  -auto-approve \
  -var-file "vars.tfvars" \
  -var="image_url=${IMAGE_URL}" \
  -var="hostname_prefix=${GITHUB_RUN_NUMBER:-testvms}" \
