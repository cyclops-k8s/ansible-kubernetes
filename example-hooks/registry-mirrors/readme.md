# Purpose
This hook will install registry mirrors on the proxy servers.

It can be used for authenticating to upstream registries since containerd 2.2.0 no longer supports authenticating to registries via the config file.

Include the `add-containerd-mirrors.yaml` to your hook list.

# Usage

You will need to use the included `haproxy.cfg` instead of the default HAProxy config file issued by the playbook to determine which proxy to go to.
You can do that by overriding the `kubernetes_proxy_haproxy_config_file` variable.

If you want to use an upstream mirror for the Distribution `Registry` image you would setup the `proxy_mirrors` variable.
It expects the following structure to be set. Note, containerd 2.2 doesn't allow credentials.

```yaml
proxy_mirrors:
- registry: docker.io
  endpoints:
  - https://my.localserver.me:5001
```

To configure the mirrors set the `registry_mirrors` variable with the following structure

```yaml
registry_mirrors:
- registry: docker.io
  data_path: "The full path to the directory to store data in."
  password: "Password, defaults to no auth to upstream"
  port: "Port on the proxies to listen on, defaults to 5001, must be unique to each mirror"
  remote_url: "The URL to proxy, defaults to https://<registry>"
  username: "Username, defaults to no auth to upstream"
  ttl: "The time to live for cached images, older images will be pruned. Use 0 to disable. Defaults to 336 hours, or 2 weeks."
```

It also expects the following variable to be set on the proxies: `registry_mirror_config_path`.
This is a full path to the directory where the configuration files will be stored.

The `registry_mirror_port` which defaults to `5000` can be set to customize the port that you pass to the mirrors.

## TODO
The `registry_mirror_certificate_file` is a path to a PEM containing the certificate to use for the registries.
If left empty it will be exposed over HTTP, which most runtimes won't support.

# Hooks

## post-proxies
The hook in `post-proxies` is to be used when running the proxy servers on their own dedicated hardware.

The file to include is `add-containerd-mirrors.yaml`.

## TODO pre-control-planes
The hook in `pre-control-planes` is designed to run in tandem (but after) with the `proxy-on-control-planes` hook.
