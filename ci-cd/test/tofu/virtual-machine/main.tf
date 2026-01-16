terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

variable "authorized_key" {
  type      = string
  sensitive = true
}

variable "base_data_volume_name" {
  type        = string
  description = "The name of the base data volume to use for the virtual machine"
}

variable "cpu_limit" {
  type        = string
  description = "The CPU limit for the virtual machine"
}

variable "cpu_request" {
  type        = string
  description = "The CPU request for the virtual machine"
}

variable "disk_size" {
  type        = string
  description = "The size of the disk to allocate to the virtual machine in Kubernetes notation"
}

variable "hostname" {
  type        = string
  description = "The prefix to use for the hostname of the virtual machine"
}

variable "memory_size" {
  type        = string
  description = "The size of memory to allocate to the virtual machine in Kubernetes notation"
}

variable "memory_size_request" {
  type        = string
  description = "The size of memory to allocate to the virtual machine in Kubernetes notation"
}

variable "namespace_name" {
  type        = string
  description = "The namespace where the resources will be created"
}

variable "networkdata_filename" {
  type        = string
  description = "Absolute path to the networkdata file"
}

variable "password" {
  type      = string
  sensitive = true
}

variable "userdata_filename" {
  type        = string
  description = "Absolute path to the userdata file"
}

output "cloud-init-secret" {
  value = kubernetes_secret_v1.cloud-init
}

output "hostname" {
  value = var.hostname
}

output "namespace_name" {
  value = var.namespace_name
}

output "ssh-service" {
  value = kubernetes_service_v1.ssh_service
}

output "virtual-machine" {
  value = kubernetes_manifest.virtual-machine.object
}
