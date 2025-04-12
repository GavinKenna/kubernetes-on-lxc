#!/bin/bash

# Source the helpers script which contians the log func
source "scripts/helpers.sh"

set -euo pipefail

LOG_DIR="./logs"
LOG_FILE="${LOG_DIR}/host-pre-req-setup-$(date +%Y%m%d-%H%M%S).log"

mkdir -p "$LOG_DIR"
log "\t📝 Logging output to $LOG_FILE"

# Step 1: Install LXD
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

# Step 2: Update system packages
log "\t🔄 Updating system packages..."
sudo apt update >> "$LOG_FILE" 2>&1
sudo apt upgrade -y >> "$LOG_FILE" 2>&1

# Step 3: Install Kubernetes and Helm prerequisites
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

# Step 4: Install Docker if not installed
if ! command -v docker &>/dev/null; then
  log "\t🔄 Docker not found, installing Docker..."
  sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common

  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
  sudo apt-get update
  sudo apt-get install -y docker-ce
  sudo systemctl start docker
  sudo systemctl enable docker
else
  log "\t\t✅ Docker is already installed."
fi

# Step 5: Install Docker Compose if not installed
if ! command -v docker-compose &>/dev/null; then
  log "\t🔄 Docker Compose not found, installing Docker Compose..."

  # Download the latest stable version of Docker Compose
  COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name)
  curl -L "https://github.com/docker/compose/releases/download/$COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

  # Apply executable permissions to the binary
  chmod +x /usr/local/bin/docker-compose

  # Verify installation
  docker-compose --version
else
  log "\t\t✅ Docker Compose is already installed."
fi

# Enable Docker to run at startup
sudo systemctl enable docker

log "✅ Host setup complete!"

