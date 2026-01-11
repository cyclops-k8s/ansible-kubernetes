# Ansible-Kubernetes - CIS hardened

## Pre-requisites

### Collections

* community.dns `ansible-galaxy collection install community.dns`
* ansible.posix `ansible-galaxy collection install ansible.posix` (required for RPM-based systems)

### Python packages

* dnspython

### Operating systems

This playbook supports both Debian-based and RPM-based Linux distributions:

It is tested on the following:

**Debian-based:**
* Ubuntu 24.04 LTS
* Ubuntu 25.10

**RPM-based:**
* CentOS Stream 9

The playbook automatically detects the OS family and uses the appropriate package manager (apt for Debian-based, dnf/yum for RPM-based distributions).

## Purpose

The purpose of this playbook and roles is to install a vanilla Kubernetes cluster with OIDC enabled hardened against the CIS Benchmark 1.12 and DOD Stig.

It is a vanilla `kubeadm` cluster that can be managed by `kubeadm` going forward, or for easy upgrades you can use the included `upgrade` playbook.

It installs HAProxy and Keepalived on the proxy nodes, this is needed for high availability of the cluster's control plane. If you decide to run the frontend of the control plane on the control planes themselves, there is an example hook that will do that for you.

It also, by default, installs `Helm` and `Kustomize` on the control plane nodes for use by the hooks. They are not required to run the playbook. This can be opted out of by setting `kubernetes_install_helm` and/or `kubernetes_install_kustomize` to `false` in your variables for the `control_plane` nodes.

## Running

Execute the `install.yaml` playbook. There are a number of configurable options (see below). It is fully configurable and does not need to be copied and modified. If there additional extension points needed in this playbook/roles then please open an issue. We gladly accept pull requests.

You will probably need to add some hooks to create a fully working cluster, at a minimum the CSI. There are example hooks for 2 different CSI's, Calico and Cilium that you can use to complete your cluster.

You will need to create 3 inventory groups.

| Group | Purpose |
|-|-|
| `proxies` | These nodes will get `keepalived` and `haproxy` on them and configured to load balance the control plane nodes. This is what your clients will connect to, by default, port 6443 |
| `kubernetes` | This will contain all of your kubernetes worker and control plane nodes |
| `control_planes` | This will contain all of your control plane nodes |
| `worker_nodes` | This will contain all of your worker nodes |

**Notes for RPM-based systems:**
* The playbook automatically installs `python3-dnf-plugin-versionlock` to enable package version pinning, which is used to prevent accidental upgrades of Kubernetes and container runtime components.
* SELinux is configured automatically on proxy nodes to allow HAProxy to connect to any port (1936 and 6443 by default). You can disable this by setting `kubernetes_configure_selinux` to `false`. Currently, no SELinux configuration is applied to Kubernetes nodes.

## Hooks
To install different pieces of the cluster, things like the CNI, CPI or CSI you can use the different hook entry points. There is a number of example hooks in the [example-hooks](example-hooks) directory.

Hooks are tasks that are imported in the different stages of the cluster.

The different hooks are as follows
* Before the control planes are configured, but after software is installed
    * One example would be to configure the proxies to run on the control planes so you don't need to have additional infrastructure.
* After the cluster is initialized
    * This is where you would install the CPI and CNI.
    * You can also use the example `add-adminbinding.yaml` hook to setup the oidc:Admins binding so members of the Admin role in your application client can fully access the cluster.
* After each control plane is added to the cluster
    * This is where you would do things that would be specific to a control plane. These tasks run on the control plane that was just added
* After all control planes are added
    * This is where you run tasks that would run on the control plane nodes. These tasks run on each of the control plane nodes.
    * If you want to run the tasks only once you can set the `run_once`.
    * If you want to use `helm` or `kustomize`, those are installed on the `first_kube_control_plane` so you can use `delegate_to` and have those run on that node.
    * A good use for this hook is setting up your local kubeconfig.
* After all worker nodes are added
    * This would be a good spot to install other applications, like bootstrapping `argocd` or installing `kubevip`.

## Configuration
I'm not going to cover every option in this section as it is vast, the name of what they do is pretty self explanatory and many comments have been added. There are a few that are required and they are noted in the default options file along with their purpose.

Each option, if it is related to a CIS benchmark or STIG, is noted in the defaults main.yml file and respective tasks in the roles.

You can see all of the different options in [roles/kubernetes-defaults/defaults/main.yml](roles/kubernetes-defaults/defaults/main.yml).

### Required Configuration Options

Before running the playbook, you **must** configure the following required variables. These can be set in your inventory file, group_vars, or passed via `-e` flag:

| Variable | Type | Description | Example |
|----------|------|-------------|---------|
| `kubernetes_control_plane_ip` | IP address | The IP address that the proxies will bind to for load balancing the Kubernetes control plane. This is the IP that HAProxy/Keepalived will listen on and kubeadm will bind the API server to. | `192.168.1.100` |
| `kubernetes_api_endpoint` | FQDN | The fully qualified domain name (FQDN) of the control plane API endpoint. Your clients will use this endpoint to interface with the cluster. **This DNS entry must already be configured and resolving before running the playbook.** | `k8s-api.example.com` |
| `kubernetes_encryption_key` | Base64 string | A 32-byte base64-encoded key used to encrypt etcd data at rest. Generate with: `head -c 32 /dev/urandom \| base64` | `xyzABC123...` (44 chars) |

#### Example Configuration

In your `group_vars/all.yml`:

```yaml
# Required: IP for proxy load balancer
kubernetes_control_plane_ip: 192.168.1.100

# Required: FQDN for API access (must have DNS resolution before running playbook)
kubernetes_api_endpoint: k8s-api.example.com

# Required: Base64-encoded 32-byte encryption key for etcd
kubernetes_encryption_key: "{{ lookup('env', 'K8S_ENCRYPTION_KEY') }}"
```

Or pass directly via command line:

```bash
ansible-playbook -i inventory install.yaml \
  -e kubernetes_control_plane_ip=192.168.1.100 \
  -e kubernetes_api_endpoint=k8s-api.example.com \
  -e kubernetes_encryption_key="YOUR_BASE64_KEY_HERE"
```

**Important:** The playbook will fail if any of these required variables are not set or are set to `null`.

## CIS Benchmark

Review the [CIS Hardening.md](CIS%20hardening.md) to see the status of each benchmark test. Most of them were handled out of the box by kubeadm, the ones that could be resolved by the playbook are.

There are some that must be handled by the administrator while using the cluster, like making sure that the default service account is not mounted by default.

TODO: Use CEL mutations to automatically mark the default service account as not automatically mounted.

## STIG's

The Kubernetes STIG Version 2 Release 1, dated 24 July 2024 has also been applied. Using the STIG viewer available for free from the DoD of the United States, you can view the checklist `Stig checklist - Kubernetes.cklb` and review what has been fixed, or not. Of the ones not fixed, there is only one
that is not up to the kubernetes administrator. It is the one related to anonymous auth of the API. RBAC restricts what the anonymous
user can access and it is required to join nodes to the cluster using Kubeadm.

The Stig viewer can be found here: [Stig Viewer](https://public.cyber.mil/stigs/srg-stig-tools/)

## Adding nodes

Just add the new nodes to your inventory and re-run the install playbook. It will automatically add the node without disrupting anything. Your hooks should check to see if they are already installed and if so, don't do anything.
