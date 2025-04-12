#!/bin/bash

# Source the helpers script which contians the log func
source "scripts/helpers.sh"

set -euo pipefail

LOG_DIR="logs"
LOG_FILE="$LOG_DIR/cleanup.log"
PROFILE="${1:-k8s}"

mkdir -p "$LOG_DIR"

# Function to stop and delete a container
stop_and_delete_container() {
  local container=$1
  if sudo lxc info "$container" &>/dev/null; then
    log "\t🛑 Stopping container: $container"
    sudo lxc stop "$container" --force >> "$LOG_FILE" 2>&1 || log "⚠️ Failed to stop $container"

    log "\t🗑️ Deleting container: $container"
    sudo lxc delete "$container" >> "$LOG_FILE" 2>&1 || log "⚠️ Failed to delete $container"
  else
    log "\tℹ️ Container $container not found. Skipping."
  fi
}

# Function to delete LXC profile
delete_profile() {
  if sudo lxc profile show "$PROFILE" &>/dev/null; then
    log "\t🧽 Deleting profile: $PROFILE"
    sudo lxc profile delete "$PROFILE" >> "$LOG_FILE" 2>&1 || log "⚠️ Failed to delete profile $PROFILE"
  else
    log "\tℹ️ Profile $PROFILE not found. Skipping."
  fi
}

# Function to clean up the local Docker registry
cleanup_registry() {
  log "🧹 Cleaning up local Docker registry..."

  # Stop and remove the registry container
  if docker ps -q -f name=secure-registry; then
    log "🛑 Stopping the registry container..."
    docker stop secure-registry >> "$LOG_FILE" 2>&1
    log "🗑️ Removing the registry container..."
    docker rm secure-registry >> "$LOG_FILE" 2>&1
  else
    log "✅ No running registry container found."
  fi

  # Optionally remove the registry volume
  if docker volume ls -q -f name=registry_data; then
    log "🧹 Removing the registry volume..."
    docker volume rm registry_data >> "$LOG_FILE" 2>&1
  else
    log "✅ No registry volume found."
  fi

  # Optionally remove the Docker network (if created)
  if docker network ls -q -f name=registry_network; then
    log "🧹 Removing the registry network..."
    docker network rm registry_network >> "$LOG_FILE" 2>&1
  else
    log "✅ No registry network found."
  fi

  # Optionally remove the registry image (uncomment to enable)
  # log "🧹 Removing the registry image..."
  # docker rmi registry:2 >> "$LOG_FILE" 2>&1

  log "✅ Local registry cleanup complete!"
}

log "\t🔧 Starting Kubernetes cleanup..."

# Stop and delete master
stop_and_delete_container "kubernetes-master"

# Detect and clean all worker nodes
log "\t🔍 Looking for worker containers..."
WORKERS=$(sudo lxc list -c n --format csv | grep '^kubernetes-worker-' || true)

for worker in $WORKERS; do
  stop_and_delete_container "$worker"
done

# Delete profile
delete_profile

# Cleanup local Docker registry
cleanup_registry

log "\t✅ Cleanup complete."
