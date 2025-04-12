#!/bin/bash

source "scripts/helpers.sh"

set -euo pipefail

LOG_DIR="logs"
LOG_FILE="$LOG_DIR/k8s-install.log"

# Default values
REGISTRY_HOST_IP=$(hostname -I | awk '{print $1}')
REGISTRY_PORT=5000
CERT_DIR="$HOME/registry-certs"
REGISTRY_DIR="$HOME/registry"
NODE_NAMES=()
OPENSSL_CONFIG="scripts/openssl-san.cnf"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --node)
      NODE_NAMES+=("$2")
      shift 2
      ;;
    *)
      log "❌ Unknown argument: $1"
      exit 1
      ;;
  esac
done

if [ ${#NODE_NAMES[@]} -eq 0 ]; then
  log "❌ No node names provided. Use --node <node-name> for each node."
  exit 1
fi

log "📦 Setting up secure local Docker registry at $REGISTRY_HOST_IP:$REGISTRY_PORT"

mkdir -p "$CERT_DIR"

# 1. Generate self-signed cert if not exists
if [[ ! -f "$CERT_DIR/domain.crt" || ! -f "$CERT_DIR/domain.key" ]]; then
  log "🔐 Generating self-signed TLS certificate..."
  openssl req -x509 -nodes -newkey rsa:2048 -keyout domain.key -out domain.crt -days 365 -config $OPENSSL_CONFIG -extensions v3_req


  cp domain* "$CERT_DIR"
fi

# 2. Create Docker Compose file
mkdir -p "$REGISTRY_DIR"
cat <<EOF > "$REGISTRY_DIR/docker-compose.yml"
version: '3'
services:
  registry:
    image: registry:2
    container_name: secure-registry
    restart: always
    ports:
      - "${REGISTRY_PORT}:${REGISTRY_PORT}"
    environment:
      REGISTRY_HTTP_ADDR: 0.0.0.0:${REGISTRY_PORT}
      REGISTRY_HTTP_TLS_CERTIFICATE: /certs/domain.crt
      REGISTRY_HTTP_TLS_KEY: /certs/domain.key
    volumes:
      - ${REGISTRY_DIR}/data:/var/lib/registry
      - ${CERT_DIR}:/certs:ro
EOF

# 3. Launch the registry
log "🚀 Starting secure registry container..."
docker-compose -f "$REGISTRY_DIR/docker-compose.yml" up -d

# 4. Push cert to all Kubernetes nodes and trust it
for node in "${NODE_NAMES[@]}"; do
  log "📥 Installing cert into $node..."
  lxc file push "$CERT_DIR/domain.crt" "$node/tmp/registry.crt"
  lxc exec "$node" -- bash -c "cp /tmp/registry.crt /usr/local/share/ca-certificates/registry.crt && update-ca-certificates"

  # Docker configuration for the registry (if Docker is in use)
  log "🔧 Configuring Docker on $node with the registry URL..."
  registry_url="http://${REGISTRY_HOST_IP}:${REGISTRY_PORT}"

  # Ensure the Docker daemon.json file exists (only for Docker, if applicable)
  lxc exec "$node" -- bash -c "mkdir -p /etc/docker && echo '{\"insecure-registries\": [\"$registry_url\"]}' > /etc/docker/daemon.json"

  # Restart Docker to apply the changes
  lxc exec "$node" -- systemctl restart docker
  log "✅ Docker configured for registry on $node."

  # containerd configuration for the registry
  log "🔧 Configuring containerd on $node with the registry URL..."

  # Modify the containerd config.toml to add the insecure registry and set cert path
  lxc exec "$node" -- bash -c "sed -i '/\[plugins.\"io.containerd.grpc.v1.cri\".\]/a insecure_registries = [\"$registry_url\"]' /etc/containerd/config.toml"

  # Ensure that the TLS settings in containerd config include proper certificate handling
  lxc exec "$node" -- bash -c "sed -i '/\[plugins.\"io.containerd.grpc.v1.cri\".\]/a [plugins.\"io.containerd.grpc.v1.cri\".registry.mirrors.\"$registry_url\"] = { ca_file = \"/usr/local/share/ca-certificates/registry.crt\" }' /etc/containerd/config.toml"

  # Restart containerd to apply the changes
  lxc exec "$node" -- systemctl restart containerd

  log "✅ containerd configured for registry on $node."
done


log "✅ Registry setup complete and trusted on all specified nodes."
