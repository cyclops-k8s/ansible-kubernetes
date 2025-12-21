extra_kubernetes_configuration = {
  containerd_registry_mirrors = [{
    registry = "_default"
    hosts = [
      {
        capabilities = [
          "pull",
          "resolve"
        ]
        host = "http://px.k8s.local:5000"
      }
    ]
  }]
}

extra_proxy_configuration = {
  kubernetes_proxy_haproxy_config_file = "{{ inventory_dir }}/../example-hooks/registry-mirrors/post-proxies/templates/haproxy.cfg.j2"
  kubernetes_hookfiles = {
    post_proxies = [
      "{{ inventory_dir }}/../example-hooks/registry-mirrors/post-proxies/add-containerd-mirrors.yaml"
    ]
  }
  registry_mirror_config_path = "/opt/mirrors/config"
  registry_mirrors = [
    {
      registry   = "docker.io"
      data_path  = "/opt/mirrors/data/docker.io"
      port       = 5001
      remote_url = "https://registry-1.docker.io"
      ttl        = "1h"
    },
    {
      registry   = "k8s.gcr.io"
      data_path  = "/opt/mirrors/data/k8s.gcr.io"
      port       = 5002
      remote_url = "https://k8s.gcr.io"
      ttl        = "1h"
    },
    {
      registry   = "quay.io"
      data_path  = "/opt/mirrors/data/quay.io"
      port       = 5003
      remote_url = "https://quay.io"
      ttl        = "1h"
    }
  ]
  registry_mirror_port = 5000
}
