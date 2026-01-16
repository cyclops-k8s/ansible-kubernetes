terraform {
  required_providers {
    ansible = {
      version = "~> 1.3.0"
      source  = "ansible/ansible"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

provider "kubernetes" {
  # config_path    = "~/.kube/config"
  # config_context = "kubernetes"
}

locals {
  kubernetes_config = {
    kubernetes_api_server_port              = 6443
    kubernetes_version                      = var.kubernetes_version
    kubernetes_cluster_name                 = "testcluster"
    kubernetes_control_plane_check_interval = "250ms"
    kubernetes_api_endpoint                 = "${module.vm-proxy.hostname}.${var.namespace_name}"
    kubernetes_encryption_key               = random_bytes.encryption_key.base64
    kubernetes_cluster_signing_duration     = "720h0m0s"
    # TODO: Replace with your own OIDC client ID for testing
    kubernetes_oidc_client_id = "test-client-id"
    # TODO: Replace with your own OIDC issuer URL for testing
    kubernetes_oidc_issuer_url                        = "https://github.com/login/oauth/"
    kubernetes_kubelet_csr_approver_regex             = ".*"
    kubernetes_kubelet_csr_approver_ips               = "0.0.0.0/0"
    kubernetes_kubelet_csr_approver_bypass_dns_checks = "true"
  }
  special_config = {
    kubernetes = {
      vars = merge(var.extra_kubernetes_configuration, {
        kubernetes_hookfiles = {
          post_cluster_init = [
            "{{ inventory_dir }}/../../../example-hooks/install-calico/post-cluster-init/install-calico.yaml",
            "{{ inventory_dir }}/../../../example-hooks/copy-admin-config/post-cluster-init/copy-admin-config.yaml"
          ]
        }
      })
    }
    proxies = {
      vars = merge(var.extra_proxy_configuration, {
        kubernetes_proxy_enable_keepalived = false
        kubernetes_proxy_bind_address      = "0.0.0.0"
      })
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

#generate random passwords and ssh keys for the VMs
resource "random_password" "vm-password" {
  length  = 16
  special = false
}

#generate ssh key pair for the VMs
resource "tls_private_key" "vm-ssh-key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "local_sensitive_file" "pem_file" {
  filename             = pathexpand("~/.ssh/${var.hostname_prefix}.pem")
  file_permission      = "600"
  directory_permission = "700"
  content              = tls_private_key.vm-ssh-key.private_key_pem
}

resource "local_file" "second_inventory" {
  content  = yamlencode(local.special_config)
  filename = "vars.yaml"
}
