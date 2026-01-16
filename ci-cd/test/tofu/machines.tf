module "vm-proxy" {
  source                = "./virtual-machine"
  base_data_volume_name = kubernetes_manifest.base_data_volume.object.metadata.name
  hostname              = "${kubernetes_manifest.base_data_volume.object.metadata.name}-px"
  password              = bcrypt(random_password.vm-password.result)
  authorized_key        = tls_private_key.vm-ssh-key.public_key_openssh
  cpu_limit             = "2"
  cpu_request           = "1"
  disk_size             = "20Gi"
  memory_size           = "2Gi"
  memory_size_request   = "1Gi"
  namespace_name        = var.namespace_name
  networkdata_filename  = "./cloud-init/network.tpl"
  userdata_filename     = "./cloud-init/user-data.tpl"
}

module "vm-controlplanes" {
    count = 3
    source = "./virtual-machine"
    base_data_volume_name = kubernetes_manifest.base_data_volume.object.metadata.name
    hostname = "${kubernetes_manifest.base_data_volume.object.metadata.name}-cp${count.index + 1}"
    password = bcrypt(random_password.vm-password.result)
    authorized_key = tls_private_key.vm-ssh-key.public_key_openssh
    cpu_limit = "2"
    cpu_request = "1"
    disk_size = "30Gi"
    memory_size = "2Gi"
    memory_size_request = "1Gi"
    namespace_name = var.namespace_name
    networkdata_filename = "./cloud-init/network.tpl"
    userdata_filename = "./cloud-init/user-data.tpl"
}

module "vm-workers" {
    count = 3
    source = "./virtual-machine"
    base_data_volume_name = kubernetes_manifest.base_data_volume.object.metadata.name
    hostname = "${kubernetes_manifest.base_data_volume.object.metadata.name}-w${count.index + 1}"
    password = bcrypt(random_password.vm-password.result)
    authorized_key = tls_private_key.vm-ssh-key.public_key_openssh
    cpu_limit = "2"
    cpu_request = "1"
    disk_size = "30Gi"
    memory_size = "2Gi"
    memory_size_request = "1Gi"
    namespace_name = var.namespace_name
    networkdata_filename = "./cloud-init/network.tpl"
    userdata_filename = "./cloud-init/user-data.tpl"
}

# data "kubernetes_resource" "control_planes" {
#     count = 3
#     kind = "VirtualMachineInstance"
#     api_version = "kubevirt.io/v1"
#     metadata {
#         name = module.vm-controlplanes[count.index].virtual-machine.metadata.name
#         namespace = var.namespace_name
#     }
# }

# data "kubernetes_resource" "workers" {
#     count = 3
#     kind = "VirtualMachineInstance"
#     api_version = "kubevirt.io/v1"
#     metadata {
#         name = module.vm-workers[count.index].virtual-machine.metadata.name
#         namespace = var.namespace_name
#     }
# }

data "kubernetes_resource" "proxy" {
    kind = "VirtualMachineInstance"
    api_version = "kubevirt.io/v1"
    metadata {
        name = module.vm-proxy.virtual-machine.metadata.name
        namespace = var.namespace_name
    }
}
