#!/bin/sh
set -e

sed "s/\${DOMAIN}/${DOMAIN:-yourdomain.com}/g" /etc/frp/frps.toml.template > /etc/frp/frps.toml

# Execute the original frps command
exec /usr/bin/frps -c /etc/frp/frps.toml

