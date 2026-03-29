# Purpose

This directory is a clean and safe place to put local configuration for the tests when running locally.

Any files ending with .tfvars will automatically be added as variable files to the `install.sh` and `upgrade.sh` scripts.


## Customize the resources for virtual machines

In a `spin-up.env` file, place the following to override the defaults

| Variable | Purpose | Default |
|-|-|-|
| CONTROL_PLANE_VM_CPU | Number of CPU's assigned to the proxy VM | 2 |
| CONTROL_PLANE_VM_MEMORY | Amount of memory assigned to the proxy VM | 2 |
| PROXY_VM_CPU | Number of CPU's assigned to the proxy VM | 2 |
| PROXY_VM_MEMORY | Amount of memory assigned to the proxy VM | 2 |
| WORKER_VM_CPU | Number of CPU's assigned to the proxy VM | 2 |
| WORKER_VM_MEMORY | Amount of memory assigned to the proxy VM | 2 |

An example to run conformance tests (passing `--conformance` to the `spin-up-test-environment.sh` script will use these values as default):

```bash
CONTROL_PLANE_VM_CPU=4
CONTROL_PLANE_VM_MEMORY=8
WORKER_VM_CPU=4
WORKER_VM_MEMORY=4
```
