# Test Environment
## Requirements

* Docker Desktop will install everything you need to run.
    * If you don't want Docker Desktop you'll need Docker and Docker Compose.
* Devcontainer extension in VSCode
* Host requires QEMU. This is already included in WSL2. Be sure to turn on nested virtualization for WSL2 for better performance.
* Host must be x86/64. Arm (Apple Silicon) is not working, we'll need someone with an Apple device to make that work.
* Must be ran through the dev container. It may work outside of the dev container, but no guarantees and issues arising from such a scenario will likely not be resolved. Too many variables.
* The dev container needs at least 24 GB available memory to run the VMs.
    * This can be provided via swap, it'll be slower, but it'll work.
* Each disk (6 of them) can get up to 20 GB which means up to 120 GB disk space. However, a basic install with no additional options is only about 6 GB.

## Purpose
This will spin up 6 VMs for testing the playbook.

* 1 proxy, px.k8s.local
* 3 control planes, cp(1-3).k8s.local
* 2 worker nodes, w(1|2).k8s.local

## Usage
To use the test harness, execute the `spin-up-test-environment.sh` file.

Once that script exits, you will have the required VMs. Then run install.sh

## How it works
### `spin-up-test-environment.sh`

The script will download the latest Ubuntu image and build VMs from that.

We use cloud-init to configure the VMs base operating system.

This `/dev/kvm` device is passed into the dev container where the `spin-up-test-environment.sh` script uses it. It spins up the above 6 VMs as the dev containers user, `vscode`.

The networking is handled using the user device type and socket device type.

Inter-vm networking is handled with the socket device driver using a multicast address.

Each VM is given 4 GB of memory and 2 cpu's.

### `install.sh`

The install script will execute Terraform to configure the playbook. It will then run the `install.yaml` playbook and install Kubernetes.
