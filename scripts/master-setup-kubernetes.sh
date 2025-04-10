#!/bin/bash

# Source the helpers script which contians the log func
source "/scripts/helpers.sh"

set -euo pipefail

LOG_DIR="logs"
LOG_FILE="$LOG_DIR/kubeinit.log"
KUBECONFIG_DIR="$HOME/.kube"
JOIN_SCRIPT="/joincluster.sh"

mkdir -p "$LOG_DIR"

log "\t🔧 Starting Kubernetes initialization..."

# Initialize Kubernetes
log "\t\t🚀 Initializing Kubernetes with kubeadm..."
if ! kubeadm init --pod-network-cidr=10.244.0.0/16 --ignore-preflight-errors=all >> "$LOG_FILE" 2>&1; then
  log_error "\t\t\t❌ kubeadm initialization failed. Check the log for details."
  exit 1
fi

# Set up kubeconfig for master
log "\t\t📁 Setting up kubeconfig for master..."
mkdir -p "$KUBECONFIG_DIR"
if ! sudo cp -i /etc/kubernetes/admin.conf "$KUBECONFIG_DIR/config"; then
  log_error "\t\t\t❌ Failed to copy kubeconfig."
  exit 1
fi
sudo chown "$(id -u):$(id -g)" "$KUBECONFIG_DIR/config" >> "$LOG_FILE" 2>&1

# Install flannel CNI
log "\t\t🌐 Installing Flannel CNI..."
if ! kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml >> "$LOG_FILE" 2>&1; then
  log_error "\t\t\t❌ Failed to install Flannel CNI."
  exit 1
fi

# Generate the join command for worker nodes
log "\t\t📝 Generating join command for worker nodes..."
if ! commandToJoin=$(kubeadm token create --print-join-command 2>/dev/null); then
  log_error "\t\t\t❌ Failed to generate the kubeadm join command."
  exit 1
fi

# Save the join command to a script
log "\t\t💾 Saving join command to $JOIN_SCRIPT..."
echo "$commandToJoin --ignore-preflight-errors=all" > "$JOIN_SCRIPT"
chmod +x "$JOIN_SCRIPT"

log "\t\t✅ Kubernetes initialization is complete!"
