resource "kubernetes_service_v1" "ssh_service" {
  metadata {
    name      = var.hostname
    namespace = var.namespace_name
  }
  spec {
    selector = {
      "vm.kubevirt.io/name" = kubernetes_manifest.virtual-machine.object.metadata.name
    }
    session_affinity = "ClientIP"
    ip_families      = ["IPv4"]
    ip_family_policy = "SingleStack"
    port {
      name        = "ssh"
      port        = 22
      protocol    = "TCP"
      target_port = 22
    }
    port {
      name        = "http"
      port        = 80
      protocol    = "TCP"
      target_port = 80
    }
    port {
      name        = "https"
      port        = 443
      protocol    = "TCP"
      target_port = 443
    }
    port {
      name        = "etcd-insecure"
      port        = 2379
      protocol    = "TCP"
      target_port = 2379
    }
    port {
      name        = "etcd-secure"
      port        = 2380
      protocol    = "TCP"
      target_port = 2380
    }
    port {
      name        = "etcd-metrics"
      port        = 2381
      protocol    = "TCP"
      target_port = 2381
    }
    port {
      name        = "kube-apiserver"
      port        = 6443
      protocol    = "TCP"
      target_port = 6443
    }

    type = "ClusterIP"
  }
}
