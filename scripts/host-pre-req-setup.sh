#!/bin/bash

set -euo pipefail

LOG_DIR="./logs"
LOG_FILE="${LOG_DIR}/host-pre-req-setup-$(date +%Y%m%d-%H%M%S).log"

# ========== Helpers ==========
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') | $*" | tee -a "$LOG_FILE"
}

mkdir -p "$LOG_DIR"
echo "📝 Logging output to $LOG_FILE"

echo "🚀 Installing LXD..." | tee -a "$LOG_FILE"
if ! snap list | grep -q '^lxd'; then
    sudo snap install lxd >> "$LOG_FILE" 2>&1
else
    echo "✅ LXD already installed, skipping." | tee -a "$LOG_FILE"
fi

echo "⚙️  Preseeding LXD config..." | tee -a "$LOG_FILE"
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

echo "📦 Creating LXD profile 'k8s'..." | tee -a "$LOG_FILE"
if ! lxc profile list | grep -q '^k8s'; then
    lxc profile create k8s >> "$LOG_FILE" 2>&1
else
    echo "✅ Profile 'k8s' already exists, skipping." | tee -a "$LOG_FILE"
fi

echo "📤 Applying k8s profile config..." | tee -a "$LOG_FILE"
cat k8s-lxc-profile | lxc profile edit k8s >> "$LOG_FILE" 2>&1

echo "🔄 Updating system packages..." | tee -a "$LOG_FILE"
sudo apt update >> "$LOG_FILE" 2>&1
sudo apt upgrade -y >> "$LOG_FILE" 2>&1

echo "📥 Installing Kubernetes and Helm prerequisites..." | tee -a "$LOG_FILE"
sudo apt-get install -y apt-transport-https ca-certificates curl gpg >> "$LOG_FILE" 2>&1

# Add Kubernetes apt repository key, only if it doesn't already exist
if [ ! -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg ]; then
  log "🔧 Downloading Kubernetes apt repository key..."
  if ! curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg >> "$LOG_FILE" 2>&1; then
    log_error "❌ Failed to add Kubernetes apt repository key."
    exit 1
  fi
else
  log "ℹ️ Kubernetes apt key already exists. Skipping download."
fi

echo "📂 Adding Kubernetes APT repo..." | tee -a "$LOG_FILE"
KUBE_LIST="/etc/apt/sources.list.d/kubernetes.list"
if [ ! -f "$KUBE_LIST" ]; then
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee "$KUBE_LIST" >> "$LOG_FILE" 2>&1
else
    echo "✅ Kubernetes repo already exists, skipping." | tee -a "$LOG_FILE"
fi

echo "🔄 Updating package index again..." | tee -a "$LOG_FILE"
sudo apt-get update >> "$LOG_FILE" 2>&1

echo "📦 Installing Helm and kubectl..." | tee -a "$LOG_FILE"
sudo apt-get install -y kubectl >> "$LOG_FILE" 2>&1
sudo snap install helm --classic >> "$LOG_FILE" 2>&1

echo "✅ Host setup complete!" | tee -a "$LOG_FILE"

