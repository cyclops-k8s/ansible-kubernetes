This hook will configure containerd to enable the device_ownership_from_security_context plugin.

This makes it so the CDI plugin for Kubernetes and KubeVirt works as expected.

Containerd can safely be restarted on a node without draining so it can be done anywhere in the playbook you want.

These are just a couple great hooks to do it in.
* `pre_prerequisites` is after the containerd configuration is rewritten during install and before the control plane components are configured.
* `post_upgrade` is after containerd is upgraded and reconfigured and before the node is uncordoned.
