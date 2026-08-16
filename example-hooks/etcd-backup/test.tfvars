extra_kubernetes_configuration = {
  kubernetes_control_plane_additional_templates = [
    {
      source      = "{{ inventory_dir }}/../example-hooks/etcd-backup/files/etcd-patch.yaml",
      destination = "{{ kubernetes_config_directory }}/patches/etcd-backuppatch.yaml",
      mode        = "0600"
    }
  ]
  kubernetes_hookfiles = {
    post_control_planes = [
      "{{ inventory_dir }}/../example-hooks/etcd-backup/etcd-backup.yaml",
    ]
    post_upgrade_control_planes = [
      "{{ inventory_dir }}/../example-hooks/etcd-backup/etcd-backup.yaml",
    ]
  }
  etcd_backup_crictl_path                          = "/usr/bin/crictl"
  etcd_backup_crictl_container_path                = "/opt/crictl"
  etcd_backup_cronjob_schedule                     = "0 0 * * *"
  etcd_backup_extra_scripts                        = []
  etcd_backup_post_backup_script = ""
  etcd_backup_snapshots_amount_to_keep             = "10"
  etcd_backup_snapshots_host_directory             = "/var/lib/etcd/snapshots"
  etcd_backup_snapshots_retention_days             = "7"
  etcd_backup_snapshot_target_volume = {
    emptyDir = {
      medium = "Memory"
    }
  }
}
