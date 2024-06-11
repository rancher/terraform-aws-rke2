#!/bin/sh

if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root" >&2
  exit 1
fi

ACTIVE="$(systemctl is-active firewalld)"
if [ "$ACTIVE" = "active" ]; then
  #https://docs.rke2.io/known_issues
  systemctl disable --now firewalld || true
  systemctl stop firewalld || true
fi

ACTIVE="$(systemctl is-active NetworkManager)"
if [ "$ACTIVE" = "active" ]; then
  touch /etc/NetworkManager/conf.d/rke2-canal.conf
  cat <<EOF > /etc/NetworkManager/conf.d/rke2-canal.conf
[keyfile]
unmanaged-devices=interface-name:cali*;interface-name:flannel*
EOF
  systemctl reload NetworkManager
fi
