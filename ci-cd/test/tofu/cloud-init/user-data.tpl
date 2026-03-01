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
- mkdir /var/lib/etcd
- mount -t tmpfs -o size=512m tmpfs /var/lib/etcd
# - sed -i 's/https:\/\//http:\/\/package-cache-proxy.cyclops-assets\/HTTPS\/\/\//g' /etc/yum.repos.d/* || true

apt:
  http_proxy: http://squid.cyclops-assets:80
  https_proxy: http://squid.cyclops-assets:80
bootcmd:
  - echo 'ftp_proxy="http://squid.cyclops-assets:80"' >> /etc/environment
  - echo 'http_proxy="http://squid.cyclops-assets:80"' >> /etc/environment
  - echo 'https_proxy="http://squid.cyclops-assets:80"' >> /etc/environment
  - echo 'no_proxy=localhost,127.0.0.1,localaddress,.localdomain.com,.cyclops-vms,.cyclops-assets' >> /etc/environment
  - echo 'FTP_PROXY="http://squid.cyclops-assets:80"' >> /etc/environment
  - echo 'HTTP_PROXY="http://squid.cyclops-assets:80"' >> /etc/environment
  - echo 'HTTPS_PROXY="http://squid.cyclops-assets:80"' >> /etc/environment
  - echo 'NO_PROXY=localhost,127.0.0.1,localaddress,.localdomain.com,.cyclops-vms,.cyclops-assets' >> /etc/environment

package_reboot_if_required: false
package_update: false
package_upgrade: false
