extra_kubernetes_configuration = {
  kubernetes_hookfiles = {
    post_control_planes = [
      "{{ inventory_dir }}/../example-hooks/etcd-defrag/etcd-defrag.yaml"
    ]
    post_upgrade_control_planes = [
      "{{ inventory_dir }}/../example-hooks/etcd-defrag/etcd-defrag.yaml"
    ]
  }
  etcd_defrag_crictl_path           = "/usr/bin/crictl"
  etcd_defrag_crictl_container_path = "/opt/crictl"
  etcd_defrag_cronjob_schedule      = "1 0 * * *"
  etcd_defrag_extra_scripts         = []
  etcd_defrag_post_execute_script   = ""
}
