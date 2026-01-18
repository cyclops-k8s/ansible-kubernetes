# Test Environment

## Requirements
KubeVirt must be configured and running in the hosting environment.

DataVolumes must be installed and enabled.

Currently it's hardcoded to use `ceph-block` as the backing storage class for the VMs.

By default it uses hardcoded default URL's for the os-images under http://assets.cyclops-assets/os-images/....
These are pulled from upstream sources and cached locally for higher performance and lower bandwidth usage. You can override the location of the image you want to use by specifying the URL environment variable when calling `spin-up-test-environment.sh`.

## Purpose
This will spin up 7 VMs for testing the playbook using KubeVirt in the runners hosting Kubernetes cluster. It will base the virtual machine name on the github run number and a random 6 character value followed by the purpose, cp(1|2|3), px, w(1|2|3).

* 1 proxy, px.k8s.local
* 3 control planes, cp(1-3).k8s.local
* 3 worker nodes, w(1|2|3).k8s.local

## Usage
To use the tests execute the `spin-up-test-environment.sh` file. If you want to test with an image besides the default latest Ubuntu LTS image, specify `--os-image` and the variant you wish to use.

Once that script exits, you will have the required VMs. Then run install.sh

### Choosing the OS Distribution

By default, the test environment uses Ubuntu 24.04. You can test with CentOS Stream 9/10 or Ubuntu 25.10 by using the `--os-image` parameter:

```bash
# Use Ubuntu 24.04 (default)
./spin-up-test-environment.sh

# Use Ubuntu 25.10
./spin-up-test-environment.sh --os-image ubuntu-25.10

# Use CentOS Stream 9
./spin-up-test-environment.sh --os-image centos9

# Use CentOS Stream 10
./spin-up-test-environment.sh --os-image centos10
```

**Note:** When testing with CentOS Stream, you may want to enable SELinux configuration, by default this is enabled:

```bash
# In test/vars.yaml, add:
# kubernetes_configure_selinux: true
```
