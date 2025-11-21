# Notes

- This task will deploy the Cilium Helm chart to the kube-system namespace only if it is not currently deployed. The task does not try to re-install the Helm chart on subsequent runs.
- The cilium.yaml.j2 is the values file used for deploying Cilium. The values used are for the version of Cilium tested. It is up to you to modify the file if a different chart version is specified.
- The defaults are from the Cilium Helm chart. Any changes to the defaults can be viewed in the [Helm chart values.yaml on GitHub](https://github.com/cilium/cilium/blob/main/install/kubernetes/cilium/values.yaml).

# Recommendations

1. Do not set the kubernetes_cilium_version variable to always get the latest version of the Helm chart.
1. Set the kubernetes_cilium_bgpControlPlane_enabled variable to install the BGP CRDs.
1. Set the kubernetes_cilium_devices variable to the bond or bridge interface on your nodes. The interface name should be the same accross all your nodes.

# Variables

These are the variables used for this hook. Variables NOT starting with kubernetes_cilium_ are inherited from the the parent ansible kubernetes roles.

| Key | Description | Required | Default | Example | Type |
| --- | ----------- | -------- | ------- | ------- | ---- |
| kubernetes_api_endpoint | Kubernetes service host. | yes | | api.example.com | string FQDN |
| kubernetes_api_port | Kubernetes service port. | yes | | 6443 | int 0-65535 |
| kubernetes_cilium_bgpControlPlane_enabled | Enables virtual BGP routers to be created via BGP CRDs | no | false | true | boolean |
| kubernetes_cilium_clusterPoolIPv4PodCIDR  | IPv4 CIDR list range to delegate to individual nodes for IPAM. | no | 10.0.0.0/8 | 10.0.0.0/8 | IPv4 Prefix/CIDR |
| kubernetes_cilium_clusterPoolIPv4MaskSize | IPv4 CIDR mask size to delegate to individual nodes for IPAM. | no | 24 | 24 | int 0-32 |
| kubernetes_cilium_clusterPoolIPv6PodCIDR  | IPv6 CIDR list range to delegate to individual nodes for IPAM. | no | "fd00::/104" | "fd00::/104" | IPv6 Prefix/CIDR |
| kubernetes_cilium_clusterPoolIPv6MaskSize | IPv6 CIDR mask size to delegate to individual nodes for IPAM. | no | 120 | 120 | int 0-128 |
| kubernetes_cilium_devices | Network interfaces that can run the eBPF datapath. | no | | "br0 br1" | space separated list as string
| kubernetes_cilium_hubble_fqdn | FQDN for Hubble. Setting this enables the Hubble ingress. | no | chart-example.local | hubble.example.com | string FQDN |
| kubernetes_cilium_hubble_ingressClassName | Name of the ingress class to use. | no | cilium | cilium | string |
| kubernetes_cilium_version | Cilium Helm chart version. An empty variable uses the latest version. Leave blank to use the latest version. | no |  | 1.19.0 | semver |
