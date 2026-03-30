#!/bin/bash

set -e

[ "${IS_CI:-false}" = "true" ] && [ -f ~/.kube/config ] && rm ~/.kube/config

cd tofu
tofu destroy \
  -auto-approve \
  -var-file "vars.tfvars"
