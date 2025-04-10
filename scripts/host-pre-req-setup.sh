#!/bin/bash

# Source the helpers script which contians the log func
source "scripts/helpers.sh"

set -euo pipefail

LOG_DIR="./logs"
LOG_FILE="${LOG_DIR}/host-pre-req-setup-$(date +%Y%m%d-%H%M%S).log"

mkdir -p "$LOG_DIR"
log "\t📝 Logging output to $LOG_FILE"

log "\t🚀 Installing LXD..."
if ! snap list | grep -q '^lxd'; then
    sudo snap install lxd >> "$LOG_FILE" 2>&1
else
    log "\t\t✅ LXD already installed, skipping."
fi

# Below is a default config for LXD. I found I needed to do so before creating the k8s profile,
# especially to use the dir driver instead of the default one (issues cropped up with the lxc containers not being
# able to download any of the containerd images.
log "\t⚙️ Preseeding LXD config..."
cat <<EOF | lxd init --preseed >> "$LOG_FILE" 2>&1
config: {}
networks: []
storage_pools:
- config: {}
  description: ""
  name: default
  driver: dir
storage_volumes: []
profiles:
- config: {}
  description: ""
  devices:
    eth0:
      name: eth0
      nictype: bridged
      parent: br0
      type: nic
    root:
      path: /
      pool: default
      type: disk
  name: default
projects: []
cluster: null
EOF

log "\t📦 Creating LXD profile 'k8s'..."
if ! lxc profile list | grep -q '^k8s'; then
    lxc profile create k8s >> "$LOG_FILE" 2>&1
else
    log "\t\t✅ Profile 'k8s' already exists, skipping."
fi

log "\t📤 Applying k8s profile config..."
cat scripts/k8s-lxc-profile | lxc profile edit k8s >> "$LOG_FILE" 2>&1

log "\t🔄 Updating system packages..."
sudo apt update >> "$LOG_FILE" 2>&1
sudo apt upgrade -y >> "$LOG_FILE" 2>&1

log "\t📥 Installing Kubernetes and Helm prerequisites..."
sudo apt-get install -y apt-transport-https ca-certificates curl gpg >> "$LOG_FILE" 2>&1

# Add Kubernetes apt repository key, only if it doesn't already exist
if [ ! -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg ]; then
  log "\t🔧 Downloading Kubernetes apt repository key..."
  if ! curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg >> "$LOG_FILE" 2>&1; then
    log_error "\t\t❌ Failed to add Kubernetes apt repository key."
    exit 1
  fi
else
  log "\t\tℹ️ Kubernetes apt key already exists. Skipping download."
fi

log "\t📂 Adding Kubernetes APT repo..."
KUBE_LIST="/etc/apt/sources.list.d/kubernetes.list"
if [ ! -f "$KUBE_LIST" ]; then
    log 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee "$KUBE_LIST" >> "$LOG_FILE" 2>&1
else
    log "\t\t✅ Kubernetes repo already exists, skipping."
fi

log "\t🔄 Updating package index again..."
sudo apt-get update >> "$LOG_FILE" 2>&1

log "\t📦 Installing Helm and kubectl..."
sudo apt-get install -y kubectl >> "$LOG_FILE" 2>&1
sudo snap install helm --classic >> "$LOG_FILE" 2>&1

log "✅ Host setup complete!" 

