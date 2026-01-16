resource "kubernetes_secret_v1" "cloud-init" {
  metadata {
    name = "${var.hostname}-cloud-init"
    namespace = var.namespace_name
  }
  data = {
    "networkdata" = templatefile(var.networkdata_filename, {
      hostname       = var.hostname
      authorized_key = var.authorized_key
      password       = var.password
    })
    "userdata" = templatefile(var.userdata_filename, {
      hostname       = var.hostname
      authorized_key = var.authorized_key
      password       = var.password
    })
  }
}
