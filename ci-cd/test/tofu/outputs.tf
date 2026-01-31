output "information" {
  value = {
    ansible = {
      inventory_file = local_file.second_inventory.filename
      pem_file       = local_sensitive_file.pem_file.filename
      groups = {
        control_planes = ansible_group.control_planes
        worker_nodes   = ansible_group.worker-nodes
        proxies        = ansible_group.proxies
        kubernetes     = ansible_group.kubernetes
      }
      hosts = {
        control_planes = ansible_host.control-planes
        proxy          = ansible_host.proxy
        worker_nodes   = ansible_host.worker-nodes
      }
    }
    control_planes = module.vm-controlplanes
    data = {
      control_planes = data.kubernetes_resource.control_planes.*.object
      proxy          = data.kubernetes_resource.proxy.object
      workers        = data.kubernetes_resource.workers.*.object
    }
    locals = {
      kubernetes_config = local.kubernetes_config
      special_config    = local.special_config
    }
    machine_names = {
      control_planes = [for cp in module.vm-controlplanes : cp.hostname]
      proxy          = module.vm-proxy.hostname
      workers        = [for w in module.vm-workers : w.hostname]
    }
    proxy       = module.vm-proxy
    vm_password = random_password.vm-password.result
    workers     = module.vm-workers
  }
  sensitive = true
}
