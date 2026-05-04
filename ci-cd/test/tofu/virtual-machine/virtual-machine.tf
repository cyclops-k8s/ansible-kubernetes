locals {
  virtual_machine_manifest = {
    apiVersion = "kubevirt.io/v1"
    kind       = "VirtualMachine"
    metadata = {
      name      = var.hostname
      namespace = var.namespace_name
      labels = {
        "cyclops.io/cluster-instance" = var.base_data_volume_name
      }
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
              storageClassName = "cyclops-block"
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
          annotations = {
            "io.cilium.no-track-port"               = "all"
            "descheduler.alpha.kubernetes.io/evict" = "true"
          }
          labels = {
            "cyclops.io/cluster-instance" = var.base_data_volume_name
          }
        }
        spec = {
          affinity = {
            nodeAffinity = {
              preferredDuringSchedulingIgnoredDuringExecution = [
                {
                  weight = 100
                  preference = {
                    matchExpressions = [
                      {
                        key      = "cyclops-k8s.io/ansible-kubernetes"
                        operator = "In"
                        values   = ["amd64"]
                      }
                    ]
                  }
                }

              ]
            }
            podAntiAffinity = {
              preferredDuringSchedulingIgnoredDuringExecution = [
                {
                  weight = 100
                  podAffinityTerm = {
                    labelSelector = {
                      matchExpressions = [
                        {
                          key      = "cyclops.io/cluster-instance"
                          operator = "In"
                          values   = [var.base_data_volume_name]
                        }
                      ]
                    }
                    topologyKey = "kubernetes.io/hostname"
                  }
                }
              ]
            }
          }
          # architecture = "amd64" # Latest version of kubevirt doesn't support this field
          domain = {
            cpu = {
              cores   = tonumber(var.cpu_limit)
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
                }
              ]
              interfaces = [
                {
                  bridge = {}
                  name   = "default"
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
            memory = merge(
              {
                guest = var.memory_size
              },
              var.hugepages_page_size != "nothing" ? {
                hugepages = {
                  pageSize = var.hugepages_page_size
                }
              } : {}
            )
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
}

resource "null_resource" "vm" {
  triggers = {
    namespace_name       = var.namespace_name
    virtual_machine_name = var.hostname
  }
  provisioner "local-exec" {
    command = "kubectl apply -f - <<< $manifest"
    environment = {
      manifest = yamlencode(local.virtual_machine_manifest)
    }
    interpreter = ["/bin/bash", "-c"]
    when        = create
  }

  provisioner "local-exec" {
    command = "kubectl delete -n \"$namespace_name\" virtualmachine \"$virtual_machine_name\""
    environment = {
      namespace_name       = self.triggers.namespace_name
      virtual_machine_name = self.triggers.virtual_machine_name
    }

    interpreter = ["/bin/bash", "-c"]
    when        = destroy
  }
}

resource "null_resource" "vm-wait" {
  provisioner "local-exec" {
    command     = "kubectl wait --for=jsonpath='{.status.printableStatus}'=Running virtualmachine -n \"$namespace_name\" --timeout=2m \"$virtual_machine_name\""
    interpreter = ["/bin/bash", "-c"]
    environment = {
      namespace_name       = var.namespace_name
      virtual_machine_name = var.hostname
    }
    when = create
  }

  depends_on = [null_resource.vm]
}
