# ETCD-DEFRAG

This hook installs a solution for periodically defragmenting etcd. This is necessary due to compaction leaving "holes" in the database files.

## How to use

Install the hook in the `post_control_planes` and `post_upgrade_control_planes` hooks.

## Variables

| Variable | Description | Default |
|-|-|-|
| `etcd_defrag_image` | The image to use for the etcd defrags. Minimum requirements are having `bash` and `jq`. | `quay.io/cyclops-k8s/swiss-army-knife:lite-latest` |
| `etcd_defrag_extra_scripts` | Array of extra files to add to the configmap, the files will be added to the `/scripts` directory in the container. | `[]` |
| `etcd_defrag_crictl_path` | Path to crictl on the host. | `/usr/bin/crictl` |
| `etcd_defrag_post_execute_script` | The script to run after the defrag is complete. If empty, no script will be ran after the defrag. | Empty string |
