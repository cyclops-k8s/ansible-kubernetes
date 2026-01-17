resource "kubernetes_manifest" "virtual-machine" {
  manifest = {
    apiVersion = "kubevirt.io/v1"
    kind       = "VirtualMachine"
    metadata = {
      name      = var.hostname
      namespace = var.namespace_name
    }
    spec = {
      dataVolumeTemplates = [
        {
          metadata = {
            name              = "${var.hostname}-disk"
            creationTimestamp = null
          }
          spec = {
            pvc = {
              accessModes = ["ReadWriteMany"]
              resources = {
                requests = {
                  storage = var.disk_size
                }
              }
              storageClassName = "ceph-block"
              volumeMode       = "Block"
            }
            source = {
              pvc = {
                name      = var.base_data_volume_name
                namespace = var.namespace_name
              }
            }
          }
        }
      ]
      runStrategy = "RerunOnFailure"
      template = {
        metadata = {
          creationTimestamp = null
        }
        spec = {
          architecture = "amd64"
          domain = {
            cpu = {
              cores   = 2
              sockets = 1
              threads = 1
            }
            devices = {
              disks = [
                {
                  name = "rootdisk"
                  disk = {
                    bus = "virtio"
                  }
                },
                {
                  name = "cloudinitdisk"
                  disk = {
                    bus = "virtio"
                  }
                  volumeName = "cloudinitdisk"
                }
              ]
              interfaces = [
                {
                  masquerade = {}
                  name       = "default"
                }
              ]
            }
            features = {
              acpi = {
                enabled = true
              }
            }
            machine = {
              type = "q35"
            }
            memory = {
              guest = var.memory_size
            }
            resources = {
              limits = {
                cpu    = var.cpu_limit
                memory = var.memory_size
              }
              requests = {
                cpu    = var.cpu_request
                memory = var.memory_size_request
              }
            }

          }
          evictionStrategy = "LiveMigrateIfPossible"
          hostname         = var.hostname
          networks = [
            {
              name = "default"
              pod  = {}
            }
          ]
          terminationGracePeriodSeconds = 5
          volumes = [
            {
              name = "rootdisk"
              dataVolume = {
                name = "${var.hostname}-disk"
              }
            },
            {
              name = "cloudinitdisk"
              cloudInitNoCloud = {
                secretRef = {
                  name = kubernetes_secret_v1.cloud-init.metadata[0].name
                }
                networkDataSecretRef = {
                  name = kubernetes_secret_v1.cloud-init.metadata[0].name
                }
              }
            }
          ]
        }
      }
    }
  }
  computed_fields = [
    "metadata.annotations",
    "metadata.labels",
    "spec.dataVolumeTemplates.metadata.creationTimestamp",
    "spec.template.metadata.creationTimestamp",
    "spec.template.spec.domain.devices.interfaces.macAddress",
  ]
  wait {
    fields = {
      "status.printableStatus" = "Running"
    }
  }
}
