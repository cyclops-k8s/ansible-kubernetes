extra_kubernetes_configuration = {
  kubernetes_hookfiles = {
    pre_configure_control_planes = [
      "{{ inventory_dir }}/../example-hooks/install-kustomize/pre-configure-control-planes/install-kustomize.yaml",
    ]
    pre_upgrade_control_planes = [
      "{{ inventory_dir }}/../example-hooks/install-kustomize/pre-upgrade-control-planes/upgrade-kustomize.yaml"
    ]
  }
}
