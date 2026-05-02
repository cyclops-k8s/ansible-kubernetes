# Purpose

This directory is a clean and safe place to put local configuration for the tests when running locally.

Any files ending with .tfvars will automatically be added as variable files to the `install.sh` and `upgrade.sh` scripts.

## Customize the resources for virtual machines

In a `spin-up.env` file, place the following to override the defaults

| Variable | Purpose | Default |
|-|-|-|
| CONTROL_PLANE_VM_CPU | Number of CPU's assigned to the proxy VM | 2 |
| CONTROL_PLANE_VM_MEMORY | Amount of memory assigned to the proxy VM | 2 |
| PROXY_VM_CPU | Number of CPU's assigned to the proxy VM | 2 |
| PROXY_VM_MEMORY | Amount of memory assigned to the proxy VM | 2 |
| WORKER_VM_CPU | Number of CPU's assigned to the proxy VM | 2 |
| WORKER_VM_MEMORY | Amount of memory assigned to the proxy VM | 2 |

An example to run conformance tests (passing `--conformance` to the `spin-up-test-environment.sh` script will use these values as default):

```bash
CONTROL_PLANE_VM_CPU=4
CONTROL_PLANE_VM_MEMORY=8
WORKER_VM_CPU=4
WORKER_VM_MEMORY=4
```

## Cloud-init customization
If there is a `user-data.txt` or `network.txt` the contents of those files will be appended to the `yq` manipulation command. They allow for manipulating the cloud-init configuration for the VM's without needing to modify files inside of checked in git repositories.
An example of something in the `user-data.txt` that could be set is the `apt`/`yum` repository url's. The contents of the file would be something like this

```
.bootcmd += [
    "sed -i 's|https://|http://cyclops-package-cache.cyclops-assets/HTTPS///|' /etc/apt/sources.list.d/* || true",
    "sed -i 's|http://|http://cyclops-package-cache.cyclops-assets/|g' /etc/apt/sources.list.d/* || true",
    "sed -i 's|https://|http://cyclops-package-cache.cyclops-assets/HTTPS///|g' /etc/yum.repos.d/* || true",
    "sed -i 's|http://|http://cyclops-package-cache.cyclops-assets/|g' /etc/yum.repos.d/* || true"
]

.apt.primary[0].arches = [ "default " ] |
.apt.primary[0].uri = "http://cyclops-package-cache.cookes.io/HTTPS///archive.ubuntu.com/ubuntu"
```

Or maybe you need to add a corporate CA cert for a company proxy or something like that. This is where you would do it.
`.ca_certs` adds the CA cert to Ubuntu using native `cloud-init`. The `write-files`/`.runcmd` works for Red-Hat based distro's.

For example:
```
.ca_certs =
{
    trusted:
    [
        "-----BEGIN CERTIFICATE-----
...
-----END CERTIFICATE-----"
    ]
} |

.write_files +=
[
    {
        content: "-----BEGIN CERTIFICATE-----

...
-----END CERTIFICATE-----",
        path: "/etc/pki/ca-trust/source/anchors/cyclops-root.crt",
        permissions: "0644"
    }
] |
.runcmd +=
[
    "update-ca-trust || true"
]
```
