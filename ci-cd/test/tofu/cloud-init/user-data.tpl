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

package_reboot_if_required: true
package_update: true
package_upgrade: true
