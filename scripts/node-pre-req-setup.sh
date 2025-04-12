#!/bin/bash

# Source the helpers script which contians the log func
source "/scripts/helpers.sh"

set -euo pipefail

LOG_DIR="logs"
LOG_FILE="$LOG_DIR/k8s-install.log"
CONFIG_KUBELET_IP="/scripts/configure-kubelet-ip.sh"

mkdir -p "$LOG_DIR"

log "\t🔧 Starting Kubernetes installation..."

# Update and install prerequisites
log "\t\t🛠️ Running apt update and upgrade..."
if ! sudo apt update -qq > "$LOG_FILE" 2>&1 && sudo apt upgrade -y -qq >> "$LOG_FILE" 2>&1; then
  log_error "❌ apt update or upgrade failed."
  exit 1
fi

log "\t\t🔧 Installing prerequisites: apt-transport-https, ca-certificates, curl, gpg..."
if ! sudo apt-get install -y apt-transport-https ca-certificates curl gpg docker.io >> "$LOG_FILE" 2>&1; then
  log_error "\t\t\t❌ Failed to install required packages."
  exit 1
fi

sudo systemctl enable docker
sudo systemctl start docker

# Add Kubernetes apt repository
log "\t\t🔧 Adding Kubernetes apt repository key..."
if ! curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg >> "$LOG_FILE" 2>&1; then
  log_error "\t\t\t❌ Failed to add Kubernetes apt repository key."
  exit 1
fi

log "\t\t🔧 Adding Kubernetes apt repository..."
if ! echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list >> "$LOG_FILE" 2>&1; then
  log_error "\t\t\t❌ Failed to add Kubernetes apt repository."
  exit 1
fi

log "\t\t🔧 Running apt-get update..."
if ! sudo apt-get update >> "$LOG_FILE" 2>&1; then
  log_error "\t\t\t❌ apt-get update failed."
  exit 1
fi

log "\t\t🔧 Installing kubelet, kubeadm, kubectl..."
if ! sudo apt-get install -y kubelet kubeadm kubectl >> "$LOG_FILE" 2>&1; then
  log_error "\t\t\t❌ Failed to install kubelet, kubeadm, kubectl."
  exit 1
fi

log "\t\t🔧 Marking kubelet, kubeadm, kubectl to be held..."
if ! sudo apt-mark hold kubelet kubeadm kubectl >> "$LOG_FILE" 2>&1; then
  log_error "\t\t\t❌ Failed to hold kubelet, kubeadm, kubectl."
  exit 1
fi

# Workaround for LXC
log "\t\t🔧 Creating symlink for /dev/kmsg to overcome LXC issue..."
if ! sudo ln -s /dev/console /dev/kmsg >> "$LOG_FILE" 2>&1; then
  log_error "\t\t\t❌ Failed to create symlink for /dev/kmsg."
  exit 1
fi

log "\t\t🔧 Enabling and starting kubelet..."
if ! sudo systemctl enable --now kubelet >> "$LOG_FILE" 2>&1; then
  log_error "\t\t\t❌ Failed to enable kubelet."
  exit 1
fi

log "\t\t\t🔧 Disabling swap..."
if ! sudo swapoff -a >> "$LOG_FILE" 2>&1; then
  log_error "\t\t\t❌ Failed to disable swap."
  exit 1
fi

log "\t\t🔧 Installing containerd..."
if ! sudo apt install -y containerd >> "$LOG_FILE" 2>&1; then
  log_error "\t\t\t❌ Failed to install containerd."
  exit 1
fi

log "\t\t🔧 Enabling and starting containerd..."
if ! sudo systemctl enable containerd >> "$LOG_FILE" 2>&1; then
  log_error "\t\t\t❌ Failed to enable containerd."
  exit 1
fi

if ! sudo systemctl start containerd >> "$LOG_FILE" 2>&1; then
  log_error "\t\t\t❌ Failed to start containerd."
  exit 1
fi

log "\t\t🔧 Configuring containerd for LXC..."
mkdir -p /etc/containerd/
if ! containerd config default | sudo tee /etc/containerd/config.toml >> "$LOG_FILE" 2>&1; then
  log_error "\t\t\t❌ Failed to configure containerd."
  exit 1
fi

log "\t\t🔧 Updating containerd config for LXC workaround..."
if ! sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml >> "$LOG_FILE" 2>&1; then
  log_error "\t\t\t❌ Failed to update containerd config."
  exit 1
fi

log "\t\t🔧 Restarting containerd and kubelet..."
if ! sudo service containerd restart >> "$LOG_FILE" 2>&1; then
  log_error "\t\t\t❌ Failed to restart containerd."
  exit 1
fi

if ! sudo service kubelet restart >> "$LOG_FILE" 2>&1; then
  log_error "\t\t\t❌ Failed to restart kubelet."
  exit 1
fi

#bash "$CONFIG_KUBELET_IP"

log "\t\t✅ Kubernetes installation is complete!"
