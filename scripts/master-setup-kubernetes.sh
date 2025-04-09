#!/bin/bash

set -euo pipefail

LOG_DIR="logs"
LOG_FILE="$LOG_DIR/kubeinit.log"
KUBECONFIG_DIR="$HOME/.kube"
JOIN_SCRIPT="/joincluster.sh"

mkdir -p "$LOG_DIR"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') | $*" | tee -a "$LOG_FILE"
}

log_error() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') | ERROR: $*" | tee -a "$LOG_FILE"
}

log "🔧 Starting Kubernetes initialization..."

# Initialize Kubernetes
log "🚀 Initializing Kubernetes with kubeadm..."
if ! kubeadm init --pod-network-cidr=10.244.0.0/16 --ignore-preflight-errors=all >> "$LOG_FILE" 2>&1; then
  log_error "❌ kubeadm initialization failed. Check the log for details."
  exit 1
fi

# Set up kubeconfig for master
log "📁 Setting up kubeconfig for master..."
mkdir -p "$KUBECONFIG_DIR"
if ! sudo cp -i /etc/kubernetes/admin.conf "$KUBECONFIG_DIR/config"; then
  log_error "❌ Failed to copy kubeconfig."
  exit 1
fi
sudo chown "$(id -u):$(id -g)" "$KUBECONFIG_DIR/config" >> "$LOG_FILE" 2>&1

# Install flannel CNI
log "🌐 Installing Flannel CNI..."
if ! kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml >> "$LOG_FILE" 2>&1; then
  log_error "❌ Failed to install Flannel CNI."
  exit 1
fi

# Generate the join command for worker nodes
log "📝 Generating join command for worker nodes..."
if ! commandToJoin=$(kubeadm token create --print-join-command 2>/dev/null); then
  log_error "❌ Failed to generate the kubeadm join command."
  exit 1
fi

# Save the join command to a script
log "💾 Saving join command to $JOIN_SCRIPT..."
echo "$commandToJoin --ignore-preflight-errors=all" > "$JOIN_SCRIPT"
chmod +x "$JOIN_SCRIPT"

log "✅ Kubernetes initialization is complete!"
