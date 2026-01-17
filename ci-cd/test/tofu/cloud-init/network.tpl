network:
  version: 2
  ethernets:
    enp1s0:
      dhcp4: true
      dhcp6: false
      dhcp4-overrides:
        use-dns: false
      nameservers:
        addresses:
          - 10.96.0.10
        search:
          - cyclops-vms
          - cyclops-vms.svc
          - cyclops-vms.svc.cluster
          - cyclops-vms.svc.cluster.local
