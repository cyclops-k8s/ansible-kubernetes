resource "random_string" "base_image_suffix" {
  length  = 6
  upper   = false
  lower   = true
  numeric = true
  special = false
}

resource "kubernetes_manifest" "base_data_volume" {
  manifest = {
    apiVersion = "cdi.kubevirt.io/v1beta1"
    kind       = "DataVolume"
    metadata = {
      name = "${var.hostname_prefix}-${random_string.base_image_suffix.result}"
      namespace = var.namespace_name
    }
    spec = {
      source = {
        http = {
          url = var.image_url
        }
      }
      pvc = {
        accessModes = ["ReadWriteMany"]
        resources = {
          requests = {
            storage = var.disk_size
          }
        }
        storageClassName = "ceph-block"
        volumeMode = "Block"
      }
    }
  }

  wait {
    fields = {
      "status.phase" = "Succeeded"
    }
  }
}
