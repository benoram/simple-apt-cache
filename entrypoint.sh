#!/bin/bash
set -e

# Create and fix permissions for runtime directory (tmpfs recreated on start)
mkdir -p /run/apt-cacher-ng
chown apt-cacher-ng:apt-cacher-ng /run/apt-cacher-ng

# Ensure cache directory has correct permissions (for mounted volumes)
chown -R apt-cacher-ng:apt-cacher-ng /var/cache/apt-cacher-ng /var/log/apt-cacher-ng

# Run expiration on startup to clean old cache entries
echo "Running cache expiration check (90 day threshold)..."
su -s /bin/sh apt-cacher-ng -c '/usr/lib/apt-cacher-ng/acngtool maint -c /etc/apt-cacher-ng/' 2>/dev/null || true

echo "Starting apt-cacher-ng..."
exec /usr/sbin/apt-cacher-ng -c /etc/apt-cacher-ng foreground=1
