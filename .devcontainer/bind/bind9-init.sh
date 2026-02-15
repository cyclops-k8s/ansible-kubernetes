#!/bin/bash
set -e

LOCAL_IP=$(ip -j address | jq '.[] | select(.ifname=="eth0") | .addr_info[] | select(.family=="inet") | .local' -r)
FORWARDER_IP=$(grep -m 1 'nameserver' /etc/resolv.conf | awk '{print $2}')

echo "[bind9-init] Detected eth0 IP: $LOCAL_IP"
echo "[bind9-init] Detected forwarder IP: $FORWARDER_IP"

# Replace the placeholder in the template and generate the actual named.conf
sudo mkdir -p /etc/bind /var/cache/bind
sudo cp .devcontainer/bind/named.conf.template /etc/bind/
sudo cp .devcontainer/bind/db.k8s.local /etc/bind/

sed "s|{{LOCAL_IP}}|$LOCAL_IP|g" /etc/bind/named.conf.template > /tmp/named.conf
sed -i "s|{{FORWARDER_IP}}|$FORWARDER_IP|g" /tmp/named.conf
sudo cp /tmp/named.conf /etc/bind/named.conf
sudo chown root:bind /etc/bind/named.conf
echo "[bind9-init] Updated /etc/bind/named.conf with local IP: $LOCAL_IP and forwarder IP: $FORWARDER_IP"
echo "[bind9-init] Starting named service, connection refused is normal and benign..."
sudo service named restart
echo "[bind9-init] Restarted named service"
