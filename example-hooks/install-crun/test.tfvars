extra_kubernetes_configuration = {
  kubernetes_hookfiles = {
    pre_prerequisites = [
      "{{ inventory_dir }}/../example-hooks/install-crun/hook.yaml",
    ]
    post_upgrade = [
      "{{ inventory_dir }}/../example-hooks/install-crun/hook.yaml",
    ]
  }
}
