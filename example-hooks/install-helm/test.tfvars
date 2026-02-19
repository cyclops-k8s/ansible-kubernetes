extra_kubernetes_configuration = {
  kubernetes_hookfiles = {
    post_cluster_init = [
      "{{ inventory_dir }}/../../example-hooks/install-helm/pre-configure-control-planes/install-helm.yaml",
    ]
    pre_upgrade_control_planes = [
      "{{ inventory_dir }}/../../example-hooks/install-helm/pre-upgrade-control-planes/upgrade-helm.yaml",
    ]
  }
}
