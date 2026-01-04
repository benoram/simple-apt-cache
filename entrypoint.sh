#!/bin/bash
set -e

# Run expiration on startup to clean old cache entries
echo "Running cache expiration check (90 day threshold)..."
/usr/lib/apt-cacher-ng/acngtool maint -c /etc/apt-cacher-ng/ 2>/dev/null || true

echo "Starting apt-cacher-ng..."
exec /usr/sbin/apt-cacher-ng -c /etc/apt-cacher-ng foreground=1
