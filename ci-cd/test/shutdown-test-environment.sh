#!/usr/bin/bash -e

cd tofu
tofu destroy \
  -auto-approve \
  -var-file "vars.tfvars"
