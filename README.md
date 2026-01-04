# Simple Apt Cache

A Docker container running apt-cacher-ng for caching APT packages. Useful for speeding up package installations across multiple Docker containers and virtual machines on a local network.

## Features

- Based on Ubuntu 25.04
- Multi-architecture support (amd64 and arm64)
- 90-day cache expiration
- Automatic weekly rebuilds via GitHub Actions
- Persistent cache storage via Docker volumes

## Quick Start

### Running the Container

```bash
# Pull and run the container
docker run -d \
  --name apt-cache \
  -p 3142:3142 \
  -v apt-cache-data:/var/cache/apt-cacher-ng \
  --restart unless-stopped \
  ghcr.io/benoram/simple-apt-cache:latest
```

### Building Locally

```bash
# Build for the current architecture
docker build -t simple-apt-cache .

# Build for multiple architectures
docker buildx build --platform linux/amd64,linux/arm64 -t simple-apt-cache .
```

## Client Configuration

### Configuring Docker Containers

#### Method 1: Build-time Configuration (Dockerfile)

Add these lines to your Dockerfile before any `apt-get` commands:

```dockerfile
# Configure apt to use the cache (replace APT_CACHE_HOST with your cache server IP/hostname)
ARG APT_CACHE_HOST=host.docker.internal
RUN echo "Acquire::http::Proxy \"http://${APT_CACHE_HOST}:3142\";" > /etc/apt/apt.conf.d/01proxy

# Now run your apt commands
RUN apt-get update && apt-get install -y <packages>
```

Build with:
```bash
docker build --build-arg APT_CACHE_HOST=192.168.1.100 -t myimage .
```

#### Method 2: Runtime Configuration (docker-compose)

```yaml
version: '3.8'
services:
  apt-cache:
    image: ghcr.io/benoram/simple-apt-cache:latest
    ports:
      - "3142:3142"
    volumes:
      - apt-cache-data:/var/cache/apt-cacher-ng
    restart: unless-stopped

  myservice:
    build:
      context: .
      args:
        APT_CACHE_HOST: apt-cache
    depends_on:
      - apt-cache

volumes:
  apt-cache-data:
```

#### Method 3: Using Docker Network

```bash
# Create a network
docker network create apt-net

# Run the cache
docker run -d --name apt-cache --network apt-net -p 3142:3142 \
  -v apt-cache-data:/var/cache/apt-cacher-ng \
  ghcr.io/OWNER/simple-apt-cache:latest

# Run containers on the same network
docker run --network apt-net -e http_proxy=http://apt-cache:3142 myimage
```

### Configuring Virtual Machines

#### Ubuntu/Debian VMs

Create the proxy configuration file:

```bash
# Replace 192.168.1.100 with your apt-cache server IP
echo 'Acquire::http::Proxy "http://192.168.1.100:3142";' | sudo tee /etc/apt/apt.conf.d/01proxy
```

#### Automatic Proxy Detection

For environments where the cache may not always be available, use this configuration:

```bash
cat << 'EOF' | sudo tee /etc/apt/apt.conf.d/01proxy
Acquire::http::Proxy-Auto-Detect "/etc/apt/detect-proxy.sh";
EOF

cat << 'EOF' | sudo tee /etc/apt/detect-proxy.sh
#!/bin/bash
APT_CACHE_HOST="192.168.1.100"
APT_CACHE_PORT="3142"

if nc -z -w 1 "$APT_CACHE_HOST" "$APT_CACHE_PORT" 2>/dev/null; then
    echo "http://${APT_CACHE_HOST}:${APT_CACHE_PORT}"
else
    echo "DIRECT"
fi
EOF

sudo chmod +x /etc/apt/detect-proxy.sh
```

#### Using with Cloud-Init

For automated VM provisioning:

```yaml
#cloud-config
write_files:
  - path: /etc/apt/apt.conf.d/01proxy
    content: |
      Acquire::http::Proxy "http://192.168.1.100:3142";
    permissions: '0644'
```

### Configuring the Local Host Server

For the server hosting the apt-cache container itself:

```bash
# Point apt to localhost since the cache is running locally
echo 'Acquire::http::Proxy "http://127.0.0.1:3142";' | sudo tee /etc/apt/apt.conf.d/01proxy
```

## Verifying the Cache is Working

### Check Cache Status

Visit the web interface at `http://<cache-host>:3142/acng-report.html`

### Test from a Client

```bash
# Clear local apt cache
sudo apt-get clean

# Update package lists (should be cached on second run)
time sudo apt-get update

# Install a package
sudo apt-get install -y htop

# Check the cache server logs
docker logs apt-cache
```

## Configuration

### Environment Variables

The container uses the following defaults which can be overridden by mounting custom config files:

| Setting | Default | Description |
|---------|---------|-------------|
| Port | 3142 | apt-cacher-ng listening port |
| ExThreshold | 90 | Days before cached files expire |
| CacheDir | /var/cache/apt-cacher-ng | Cache storage location |

### Custom Configuration

Mount a custom config file:

```bash
docker run -d \
  --name apt-cache \
  -p 3142:3142 \
  -v apt-cache-data:/var/cache/apt-cacher-ng \
  -v ./my-acng.conf:/etc/apt-cacher-ng/acng.conf:ro \
  ghcr.io/OWNER/simple-apt-cache:latest
```

## Exposed Ports

| Port | Protocol | Description |
|------|----------|-------------|
| 3142 | TCP | apt-cacher-ng proxy and web interface |

## Volumes

| Path | Description |
|------|-------------|
| /var/cache/apt-cacher-ng | Cache storage (persist this!) |

## Troubleshooting

### Cache Not Working

1. Verify the container is running:
   ```bash
   docker ps | grep apt-cache
   ```

2. Check container logs:
   ```bash
   docker logs apt-cache
   ```

3. Test connectivity from client:
   ```bash
   curl http://<cache-host>:3142/acng-report.html
   ```

4. Verify proxy configuration on client:
   ```bash
   apt-config dump | grep -i proxy
   ```

### HTTPS Repositories

apt-cacher-ng passes through HTTPS connections. For repositories using HTTPS, packages will be fetched directly without caching. To maximize cache hits, prefer HTTP mirrors when possible.

### Clearing the Cache

```bash
# Stop the container
docker stop apt-cache

# Remove the volume
docker volume rm apt-cache-data

# Restart the container (creates fresh volume)
docker start apt-cache
```

## License

MIT
