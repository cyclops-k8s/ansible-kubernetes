# Ansible-Kubernetes - CIS hardened

## Pre-requisites

### Collections

* community.dns `ansible-galaxy collection install community.dns`

### Python packages

* dnspython

### Operating systems

* Currently the only supported Linux distribution is Ubuntu. This has been tested on 22.04, 24.04, 24.10 and 25.04.

## Purpose

The purpose of this playbook and roles is to install a vanilla Kubernetes cluster with OIDC enabled hardened against the CIS Benchmark and DOD Stig.

It is a vanilla `kubeadm` cluster that can be managed by `kubeadm` going forward, or for easy upgrades you can use the included `upgrade` playbook.

It installs HAProxy and Keepalived on the proxy nodes, this is needed for high availability of the cluster's control plane. If you decide to run the frontend of the control plane on the control planes themselves, there is an example hook that will do that for you.

It also, by default, installs `Helm` and `Kustomize` on the control plane nodes for use by the hooks. They are not required to run the playbook. This can be opted out of by setting `kubernetes_install_helm` and/or `kubernetes_install_kustomize` to `false` in your variables for the `control_plane` nodes.

## Running

Execute the `install.yml` playbook. There are a number of configurable options (see below). It is fully configurable and does not need to be copied and modified. If there additional extension points needed in this playbook/roles then please open an issue. We gladly accept pull requests.

This playbook is currently tested on Ubuntu 24.04 LTS.

You will probably need to add some hooks to create a fully working cluster, at a minimum the CSI. There are example hooks for 2 different CSI's, Calico and Cilium that you can use to complete your cluster.

You will need to create 3 inventory groups.

| Group | Purpose |
|-|-|
| `proxies` | These nodes will get `keepalived` and `haproxy` on them and configured to load balance the control plane nodes. This is what your clients will connect to, by default, port 6443 |
| `kubernetes` | This will contain all of your kubernetes worker and control plane nodes |
| `control_planes` | This will contain all of your control plane nodes |
| `worker_nodes` | This will contain all of your worker nodes |

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
