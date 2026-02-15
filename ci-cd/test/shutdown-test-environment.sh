#!/usr/bin/bash

set -e

cd tofu
tofu destroy \
  -auto-approve \
  -var-file "vars.tfvars"
