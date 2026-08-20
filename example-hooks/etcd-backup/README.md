# ETCD-Backup

This hook installs a solution for backing up etcd to targets.

By default it will store the backups in an emtpyDir volume stored in memory. Effectively its just making sure it works. It's not useful until you specify the `etcd_backup_snapshot_target_volume` to store in a persistent location or use the `etcd_backup_extra_scripts` to include other scripts and `etcd_backup_post_execute_script` to execute them and store the backup in a different location.

The name of the snapshot file is stored in the environment variable `SNAPSHOT_FILENAME`

The full path to the snapshot file is in the environment variable `SNAPSHOT_PATH`

This is strictly the etcd database, it does not include the encryption key used by the Kubernetes API server to encrypt the data inside of it.

## How to use

* Install the hook in the `post_control_planes` hooks
* If you want to store your snapshots somewhere other than /var/lib/etcd/snapshots, copy the `etcd-patch.yaml` file as an additional etcd patch to `{{ kubernetes_config_directory }}/patches/etcd-backuppatch.yaml`

## Variables

| Variable | Description | Default |
|-|-|-|
| `etcd_backup_iimage` | The image to use for the etcd backups. Minimum requirements are having `bash` and `jq`. | `quay.io/cyclops-k8s/swiss-army-knife:lite-latest` |
| `etcd_backup_extra_scripts` | Array of extra files to add to the configmap, the files will be added to the `/scripts` directory in the container. | `[]` |
| `etcd_backup_snapshots_amount_to_keep` | Maximum number of snapshot files to keep in the target directory. When an empty string or non numeric value this criteria will not be validated when cleaning up old files. | `10` |
| `etcd_backup_crictl_path` | Path to crictl in the container. | `/usr/bin/crictl` |
| `etcd_backup_snapshots_host_directory` | The directory on the host system that the snapshots get saved to. | `/var/lib/etcd/snapshots` |
| `etcd_backup_snapshots_retention_days` | The max age of backups to retain. If not set this retention policy is not applied. | `7` |
| `etcd_backup_snapshot_target_volume` | The volume spec in the cronjob for moving the snapshot files to | Its an emptyDir volume with medium memory, no backups will be retained. |
| `etcd_backup_post_execute_script` | The script to run after the backup is complete. If empty, no script will be ran after the backup. | Empty string |
