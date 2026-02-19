extra_kubernetes_configuration = {
  kubernetes_hookfiles = {
    pre_prerequisites = [
      "{{ inventory_dir }}/../example-hooks/containerd-config-customization/hook.yaml",
    ]
    post_upgrade = [
      "{{ inventory_dir }}/../example-hooks/containerd-config-customization/hook.yaml",
    ]
  }
}
