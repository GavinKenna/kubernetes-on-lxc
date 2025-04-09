#!/bin/bash

set -euo pipefail

LOG_DIR="logs"
LOG_FILE="$LOG_DIR/k8s-install.log"

mkdir -p "$LOG_DIR"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') | $*" | tee -a "$LOG_FILE"
}

log_error() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') | ERROR: $*" | tee -a "$LOG_FILE"
}

log "🔧 Starting Kubernetes installation..."

# Update and install prerequisites
log "🛠️ Running apt update and upgrade..."
if ! sudo apt update && sudo apt upgrade -y >> "$LOG_FILE" 2>&1; then
  log_error "❌ apt update or upgrade failed."
  exit 1
fi

log "🔧 Installing prerequisites: apt-transport-https, ca-certificates, curl, gpg..."
if ! sudo apt-get install -y apt-transport-https ca-certificates curl gpg >> "$LOG_FILE" 2>&1; then
  log_error "❌ Failed to install required packages."
  exit 1
fi

# Add Kubernetes apt repository
log "🔧 Adding Kubernetes apt repository key..."
if ! curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg >> "$LOG_FILE" 2>&1; then
  log_error "❌ Failed to add Kubernetes apt repository key."
  exit 1
fi

log "🔧 Adding Kubernetes apt repository..."
if ! echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list >> "$LOG_FILE" 2>&1; then
  log_error "❌ Failed to add Kubernetes apt repository."
  exit 1
fi

log "🔧 Running apt-get update..."
if ! sudo apt-get update >> "$LOG_FILE" 2>&1; then
  log_error "❌ apt-get update failed."
  exit 1
fi

log "🔧 Installing kubelet, kubeadm, kubectl..."
if ! sudo apt-get install -y kubelet kubeadm kubectl >> "$LOG_FILE" 2>&1; then
  log_error "❌ Failed to install kubelet, kubeadm, kubectl."
  exit 1
fi

log "🔧 Marking kubelet, kubeadm, kubectl to be held..."
if ! sudo apt-mark hold kubelet kubeadm kubectl >> "$LOG_FILE" 2>&1; then
  log_error "❌ Failed to hold kubelet, kubeadm, kubectl."
  exit 1
fi

# Workaround for LXC
log "🔧 Creating symlink for /dev/kmsg to overcome LXC issue..."
if ! sudo ln -s /dev/console /dev/kmsg >> "$LOG_FILE" 2>&1; then
  log_error "❌ Failed to create symlink for /dev/kmsg."
  exit 1
fi

log "🔧 Enabling and starting kubelet..."
if ! sudo systemctl enable --now kubelet >> "$LOG_FILE" 2>&1; then
  log_error "❌ Failed to enable kubelet."
  exit 1
fi

log "🔧 Disabling swap..."
if ! sudo swapoff -a >> "$LOG_FILE" 2>&1; then
  log_error "❌ Failed to disable swap."
  exit 1
fi

log "🔧 Installing containerd..."
if ! sudo apt install -y containerd >> "$LOG_FILE" 2>&1; then
  log_error "❌ Failed to install containerd."
  exit 1
fi

log "🔧 Enabling and starting containerd..."
if ! sudo systemctl enable containerd >> "$LOG_FILE" 2>&1; then
  log_error "❌ Failed to enable containerd."
  exit 1
fi

if ! sudo systemctl start containerd >> "$LOG_FILE" 2>&1; then
  log_error "❌ Failed to start containerd."
  exit 1
fi

log "🔧 Configuring containerd for LXC..."
mkdir -p /etc/containerd/
if ! containerd config default | sudo tee /etc/containerd/config.toml >> "$LOG_FILE" 2>&1; then
  log_error "❌ Failed to configure containerd."
  exit 1
fi

log "🔧 Updating containerd config for LXC workaround..."
if ! sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml >> "$LOG_FILE" 2>&1; then
  log_error "❌ Failed to update containerd config."
  exit 1
fi

log "🔧 Restarting containerd and kubelet..."
if ! sudo service containerd restart >> "$LOG_FILE" 2>&1; then
  log_error "❌ Failed to restart containerd."
  exit 1
fi

if ! sudo service kubelet restart >> "$LOG_FILE" 2>&1; then
  log_error "❌ Failed to restart kubelet."
  exit 1
fi

log "✅ Kubernetes installation is complete!"
