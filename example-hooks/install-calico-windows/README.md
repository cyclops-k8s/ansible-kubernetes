# install-calico-windows

Configures the Tigera Operator's `Installation` custom resource for Windows node (HNS dataplane)
support, and deploys kube-proxy for Windows nodes as a HostProcess DaemonSet, so pods can be
scheduled on Windows worker nodes (`windows_worker_nodes` inventory group).

Calico no longer ships a standalone `calico-windows-vxlan.yaml` manifest (removed upstream) -
the Tigera Operator is now the only officially supported way to run Calico on Windows nodes. See
[Install using Operator](https://docs.tigera.io/calico/latest/getting-started/kubernetes/windows-calico/operator).

## Requirements

* The existing [`example-hooks/install-calico`](../install-calico) hook must also be installed
  first - it installs the Tigera Operator and creates the `default` `Installation`/`APIServer`
  custom resources that this hook patches. Calico must already be running via the operator before
  this hook runs.
* `kubernetes_windows_cni: calico` and `kubernetes_windows_cni_calico_mode: vxlan` (the defaults)
  must match whatever overlay mode the Linux Calico install uses, otherwise pod networking will
  not work across Linux and Windows nodes.

## Usage

Reference both hooks under the same `post_cluster_init` hook point, Linux hook first. Also
reference the Calico VXLAN firewall rule hook under `post_configure_windows_workers` - it's kept
separate from `roles/container-runtime-windows` since that role has no guarantee about which CNI
a given cluster uses:

```yaml
kubernetes_hookfiles:
  post_cluster_init:
    - /path/to/example-hooks/install-calico/post-cluster-init/install-calico.yaml
    - /path/to/example-hooks/install-calico-windows/post-cluster-init/install-calico-windows.yaml
  post_configure_windows_workers:
    - /path/to/example-hooks/install-calico-windows/post_configure_windows_workers/configure-calico-vxlan-firewall.yaml
```

This is idempotent - it checks for the `kube-proxy-windows` DaemonSet before applying changes.
