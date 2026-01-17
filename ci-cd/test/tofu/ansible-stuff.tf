resource "ansible_group" "control_planes" {
  name = "control_planes"
}

resource "ansible_group" "worker-nodes" {
  name = "worker_nodes"
}

resource "ansible_group" "proxies" {
  name = "proxies"
}

resource "ansible_group" "kubernetes" {
  name      = "kubernetes"
  variables = local.kubernetes_config
}

resource "ansible_host" "control-planes" {
  count  = 3
  name   = "${kubernetes_manifest.base_data_volume.object.metadata.name}-cp${count.index + 1}.${var.namespace_name}"
  groups = ["control_planes", "kubernetes"]
  variables = {
    ansible_host                       = "${kubernetes_manifest.base_data_volume.object.metadata.name}-cp${count.index + 1}.${var.namespace_name}"
    ansible_ssh_common_args            = "-o StrictHostKeyChecking=no"
    ansible_ssh_private_key_file       = "~/.ssh/${var.hostname_prefix}.pem"
    ansible_user                       = "ansible"
    ip_address                         = data.kubernetes_resource.control_planes[count.index].object.status.interfaces[0].ipAddress
    kubernetes_api_server_bind_address = data.kubernetes_resource.control_planes[count.index].object.status.interfaces[0].ipAddress
    kubernetes_kubelet_node_ip         = data.kubernetes_resource.control_planes[count.index].object.status.interfaces[0].ipAddress
  }
}

resource "ansible_host" "worker-nodes" {
  count  = 2
  name   = "${kubernetes_manifest.base_data_volume.object.metadata.name}-w${count.index + 1}.${var.namespace_name}"
  groups = ["worker_nodes", "kubernetes"]
  variables = {
    ansible_host                       = "${kubernetes_manifest.base_data_volume.object.metadata.name}-w${count.index + 1}.${var.namespace_name}"
    ansible_ssh_common_args            = "-o StrictHostKeyChecking=no"
    ansible_ssh_private_key_file       = "~/.ssh/${var.hostname_prefix}.pem"
    ansible_user                       = "ansible"
    ip_address                         = data.kubernetes_resource.workers[count.index].object.status.interfaces[0].ipAddress
    kubernetes_api_server_bind_address = data.kubernetes_resource.workers[count.index].object.status.interfaces[0].ipAddress
    kubernetes_kubelet_node_ip         = data.kubernetes_resource.workers[count.index].object.status.interfaces[0].ipAddress
  }
}

resource "ansible_host" "proxy" {
  name   = module.vm-proxy.hostname
  groups = ["proxies"]
  variables = {
    ansible_host                  = "${module.vm-proxy.hostname}.${var.namespace_name}"
    ansible_ssh_common_args       = "-o StrictHostKeyChecking=no"
    ansible_ssh_private_key_file  = "~/.ssh/${var.hostname_prefix}.pem"
    ansible_user                  = "ansible"
    control_plane_ip              = data.kubernetes_resource.proxy.object.status.interfaces[0].ipAddress
    kubernetes_proxy_bind_address = data.kubernetes_resource.proxy.object.status.interfaces[0].ipAddress
    vrrp_priority                 = 1
    vrrp_state                    = "BACKUP" #count.index == 0 ? "MASTER" : "BACKUP"
    vrrp_password                 = random_password.proxy_vrrp_password.result
    vrrp_interface                = "enp1s0"
    vrrp_virtual_router_id        = 1
  }
}
