#!/bin/bash

set -euo pipefail

LOG_DIR="logs"
LOG_FILE="$LOG_DIR/cleanup.log"
PROFILE="${1:-k8s}"

mkdir -p "$LOG_DIR"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') | $*" | tee -a "$LOG_FILE"
}

stop_and_delete_container() {
  local container=$1
  if sudo lxc info "$container" &>/dev/null; then
    log "🛑 Stopping container: $container"
    sudo lxc stop "$container" --force >> "$LOG_FILE" 2>&1 || log "⚠️ Failed to stop $container"

    log "🗑️ Deleting container: $container"
    sudo lxc delete "$container" >> "$LOG_FILE" 2>&1 || log "⚠️ Failed to delete $container"
  else
    log "ℹ️ Container $container not found. Skipping."
  fi
}

delete_profile() {
  if sudo lxc profile show "$PROFILE" &>/dev/null; then
    log "🧽 Deleting profile: $PROFILE"
    sudo lxc profile delete "$PROFILE" >> "$LOG_FILE" 2>&1 || log "⚠️ Failed to delete profile $PROFILE"
  else
    log "ℹ️ Profile $PROFILE not found. Skipping."
  fi
}

log "🔧 Starting Kubernetes cleanup..."

# Stop and delete master
stop_and_delete_container "kubernetes-master"

# Detect and clean all worker nodes
log "🔍 Looking for worker containers..."
WORKERS=$(sudo lxc list -c n --format csv | grep '^kubernetes-worker-' || true)

for worker in $WORKERS; do
  stop_and_delete_container "$worker"
done

# Delete profile
delete_profile

log "✅ Cleanup complete."

