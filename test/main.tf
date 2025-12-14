terraform {
  required_providers {
    ansible = {
      version = "~> 1.3.0"
      source  = "ansible/ansible"
    }
  }
}

resource "random_bytes" "encryption_key" {
  length = 32
}

resource "random_password" "proxy_vrrp_password" {
  length  = 8
  special = false
}

resource "ansible_host" "control-plane" {
  count  = 3
  name   = "cp${count.index + 1}.k8s.local"
  groups = ["control_planes", "kubernetes"]
  variables = {
    ansible_host = "cp${count.index + 1}.k8s.local"
    ip_address   = "10.255.254.${count.index + 12}"
  }
}

resource "ansible_host" "worker-nodes" {
  count  = 2
  name   = "w${count.index + 1}.k8s.local"
  groups = ["worker_nodes", "kubernetes"]
  variables = {
    ansible_host = "w${count.index + 1}.k8s.local"
    ip_address   = "10.255.254.${count.index + 15}"
  }
}

resource "ansible_host" "proxy" {
  name   = "px.k8s.local"
  groups = ["proxies"]
  variables = {
    ansible_host                       = "px.k8s.local"
    vrrp_priority                      = 1
    vrrp_state                         = "BACKUP" #count.index == 0 ? "MASTER" : "BACKUP"
    vrrp_password                      = random_password.proxy_vrrp_password.result
    vrrp_interface                     = "ens4"
    vrrp_virtual_router_id             = 1
    control_plane_ip                   = "10.255.254.11"
  }
}

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

locals {
  kubernetes_config = {
    kubernetes_api_server_port              = 6443
    kubernetes_version                      = var.kubernetes_version
    kubernetes_cluster_name                 = "testcluster"
    kubernetes_control_plane_check_interval = "250ms"
    kubernetes_api_endpoint                 = "cp.k8s.local"
    kubernetes_encryption_key               = random_bytes.encryption_key.base64
    kubernetes_cluster_signing_duration     = "720h0m0s"
    # TODO: Replace with your own OIDC client ID for testing
    kubernetes_oidc_client_id = "test-client-id"
    # TODO: Replace with your own OIDC issuer URL for testing
    kubernetes_oidc_issuer_url                        = "https://github.com/login/oauth/"
    kubernetes_kubelet_csr_approver_regex             = "^(cp|w)[0-9]+$"
    kubernetes_kubelet_csr_approver_ips               = "10.255.254.0/24"
    kubernetes_kubelet_csr_approver_bypass_dns_checks = "true"
    kubernetes_proxy_bind_address                     = "0.0.0.0"
    kubernetes_proxy_enable_keepalived                = false
  }
  special_config = {
    kubernetes = {
      vars = {
        kubernetes_hookfiles = {
          post_cluster_init = [
            "{{ inventory_dir }}/../example-hooks/install-calico/post-cluster-init/install-calico.yaml",
            "{{ inventory_dir }}/../example-hooks/copy-admin-config/post-cluster-init/copy-admin-config.yaml"
          ]
        }
      }
    }
    proxies = {
      vars = {
        kubernetes_proxy_enable_keepalived = false
      }
    }
  }
}

resource "local_file" "second_inventory" {
  content  = yamlencode(local.special_config)
  filename = "vars.yaml"
}

variable "kubernetes_version" {
  type    = string
  default = "1.34"
}
