variable "control_plane_memory_size" {
  type        = string
  description = "The memory size for the control plane virtual machines in Gi"
  default     = "4"
}

variable "disk_size" {
  type        = string
  description = "The size of the disk in Kubernetes notation"
  default     = "20Gi"
}

variable "kubernetes_version" {
  type    = string
  default = "1.36"
}

variable "extra_proxy_configuration" {
  type    = any
  default = {}
}

variable "extra_kubernetes_configuration" {
  type    = any
  default = {}
}

variable "hostname_prefix" {
  type        = string
  description = "The prefix to use for the hostname of the virtual machine"
  default     = "test"
}

variable "image_url" {
  type        = string
  description = "The URL of the image to use for the proxy VM"
  default     = "http://assets.cyclops-assets/os-images/noble-server-cloudimg-amd64.img"
}

variable "namespace_name" {
  type        = string
  description = "The namespace in which to create the virtual machines"
  default     = "cyclops-vms"
}

variable "worker_memory_size" {
  type        = string
  description = "The memory size for the worker virtual machines in Gi"
  default     = "2"
}
