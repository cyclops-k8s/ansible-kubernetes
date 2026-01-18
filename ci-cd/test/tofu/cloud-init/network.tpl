network:
  version: 2
  ethernets:
    enp1s0:
      dhcp4: true
      dhcp6: false
      nameservers:
        search:
        - cyclops-vms
        - cyclops-vms.svc
        - cyclops-vms.svc.cluster
        - cyclops-vms.svc.cluster.local
