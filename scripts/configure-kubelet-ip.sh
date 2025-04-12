#!/bin/bash

# This script is for fixing an issue I came across with k8s on LXC. Basically the worker nodes wouldn't
# show any logs, but the master could. Turns out the wrong ip was being set nad we need to use --node-ip

source "/scripts/helpers.sh"

set -euo pipefail

LOG_DIR="./logs"
LOG_FILE="${LOG_DIR}/kubelet-ip-$(date +%Y%m%d-%H%M%S).log"

mkdir -p "$LOG_DIR"
log "\t📝 Logging output to $LOG_FILE"

exec > >(tee -a "$LOG_FILE") 2>&1


NODE_IP=$(ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
log "Setting kubelet node IP to $NODE_IP..."

touch /etc/default/kubelet

# Path to the kubeadm flags file
KUBEADM_FLAGS_FILE="/var/lib/kubelet/kubeadm-flags.env"

# Check if the file exists
if [ -f "$KUBEADM_FLAGS_FILE" ]; then
    # Read the current content of the file
    CURRENT_FLAGS=$(cat "$KUBEADM_FLAGS_FILE")

    # Check if the node-ip argument already exists
    if [[ "$CURRENT_FLAGS" != *"--node-ip"* ]]; then
        # Append the node-ip argument to the existing flags
        echo "Appending --node-ip=$NODE_IP to kubeadm flags"
        # Modify the existing KUBELET_KUBEADM_ARGS line in the file
        sed -i "/KUBELET_KUBEADM_ARGS=/ s|\"$| --node-ip=$NODE_IP\"|" "$KUBEADM_FLAGS_FILE"
    else
        echo "--node-ip is already set in kubeadm flags"
    fi
else
    echo "$KUBEADM_FLAGS_FILE does not exist. Creating the file."
    # If the file doesn't exist, create it with the node-ip argument
    echo "KUBELET_KUBEADM_ARGS=\"--container-runtime-endpoint=unix:///var/run/containerd/containerd.sock --pod-infra-container-image=registry.k8s.io/pause:3.1 --node-ip=$NODE_IP\"" > "$KUBEADM_FLAGS_FILE"
fi
# default kubelet args
sudo sed -i "/^KUBELET_EXTRA_ARGS=/d" /etc/default/kubelet || true
log "KUBELET_EXTRA_ARGS=\"--node-ip=$NODE_IP\"" | sudo tee /etc/default/kubelet

# Restart
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl restart kubelet

log "Kubelet configured successfully!"