#!/bin/bash
# Publish a single mDNS alias (e.g. customer.local) pointing to the primary LAN IP.
# Used by the food-orders-mdns@.service systemd template.
set -e

HOSTNAME="$1"
if [ -z "$HOSTNAME" ]; then
  echo "usage: $0 <hostname>" >&2
  exit 1
fi

IP=$(ip -4 -o addr show scope global | awk '$2 !~ /^(docker|br-|veth)/ {split($4,a,"/"); print a[1]; exit}')
if [ -z "$IP" ]; then
  echo "could not determine LAN IP" >&2
  exit 1
fi

echo "publishing $HOSTNAME -> $IP"
exec avahi-publish -a -R "$HOSTNAME" "$IP"
