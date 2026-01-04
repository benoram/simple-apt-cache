FROM ubuntu:25.04

LABEL org.opencontainers.image.title="simple-apt-cache"
LABEL org.opencontainers.image.description="APT package caching proxy using apt-cacher-ng"
LABEL org.opencontainers.image.source="https://github.com/benoram/apt-cacher"

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install apt-cacher-ng and clean up in a single layer
# Using --no-install-recommends to minimize image size
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
        apt-cacher-ng \
        ca-certificates \
        curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create cache and log directories with proper permissions
RUN mkdir -p /var/cache/apt-cacher-ng /var/log/apt-cacher-ng && \
    chown -R apt-cacher-ng:apt-cacher-ng /var/cache/apt-cacher-ng /var/log/apt-cacher-ng

# Copy configuration files
COPY config/acng.conf /etc/apt-cacher-ng/acng.conf
COPY config/security.conf /etc/apt-cacher-ng/security.conf

# Copy and set up entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose apt-cacher-ng default port
EXPOSE 3142

# Volume for persistent cache storage
VOLUME ["/var/cache/apt-cacher-ng"]

# Health check to verify apt-cacher-ng is responding
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3142/acng-report.html || exit 1

# Run as apt-cacher-ng user for security
USER apt-cacher-ng

ENTRYPOINT ["/entrypoint.sh"]
