#cloud-config

hostname: ${hostname}
manage_etc_hosts: true
fqdn: ${hostname}

users:
- name: ansible
  gecos: ansible
  sudo: ["ALL=(ALL) NOPASSWD:ALL"]
  groups: sudo
  shell: /bin/bash
  passwd: ${password}
  lock_passwd: false
  ssh_authorized_keys:
  - ${ authorized_key }
timezone: Etc/UTC

ssh_pwauth: true
chpasswd:
  expire: false

runcmd:
- |
    mkdir /var/lib/etcd
    mount -t tmpfs -o size=512m tmpfs /var/lib/etcd

write_files:
- content: Acquire::http::Proxy "http://package-cache.cyclops-assets";
  owner: root:root
  path: /etc/apt/apt.conf.d/00cacher
  permissions: '0644'

package_reboot_if_required: false
package_update: false
package_upgrade: false
