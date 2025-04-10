#!/bin/bash

set -euo pipefail

# ========== Configuration ==========
NUM_WORKERS=${1:-2}
PROFILE="k8s"
IMAGE="ubuntu:24.04"
MASTER_NAME="kubernetes-master"

LOG_DIR="logs"
LOG_FILE="$LOG_DIR/setup.log"
mkdir -p "$LOG_DIR"

HOST_PRE_REQ_SCRIPT="scripts/host-pre-req-setup.sh"
NODE_PRE_REQ_SCRIPT="scripts/node-pre-req-setup.sh"
MASTER_INIT_KUBERNETES_SCRIPT="scripts/master-setup-kubernetes.sh"
WORKER_NODE_CONNECT_TO_KUBERNETES_SCRIPT="scripts/worker-node-connect-to-kubernetes.sh"
INSTALL_TOOLS_SCRIPT="scripts/install-tools.sh"
TEARDOWN_SCRIPT="scripts/teardown.sh"
HELPERS_SCRIPT="scripts/helpers.sh"


show_help() {
  cat <<EOF
Usage: ./setup.sh [OPTIONS]

This script sets up a Kubernetes cluster with LXC containers as nodes and installs required tools.

Options:
  -h, --help          Show this help message and exit.
  -p, --num-workers   Number of worker nodes (default: 2).
  -i, --install-tools Install necessary tools on the host.
  -m, --monitoring     Install monitoring stack with Prometheus and Grafana (default: true).
  -c, --cleanup        Clean up Kubernetes setup (stop and delete containers).
EOF
}

# Default options
NUM_WORKERS=2
INSTALL_TOOLS=true
INSTALL_MONITORING=true
CLEANUP=false
INSTALL_HOST_PREREQS=true

# Source the helpers script which contians the log func
source $HELPERS_SCRIPT

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      show_help
      exit 0
      ;;
    -p|--num-workers)
      NUM_WORKERS=$2
      shift 2
      ;;
    -i|--install-tools)
      INSTALL_TOOLS=true
      shift
      ;;
    -m|--monitoring)
      INSTALL_MONITORING=true
      shift
      ;;
    -c|--cleanup)
      CLEANUP=true
      shift
      ;;
    *)
      log_error "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
done

run_pre_req_setup() {
  NODE_NAME=$1
  log "🔧 Running pre-req setup on $NODE_NAME..."
  sudo lxc exec "$NODE_NAME" -- /bin/bash /install.sh 2>&1 | tee -a "$LOG_FILE" || {
    log "❌ Failed pre-reqs on $NODE_NAME"
    exit 1
  }
}

# ========== Option Parsing ==========
for arg in "$@"; do
  case $arg in
    --no-host-setup)
      INSTALL_HOST_PREREQS=false
      ;;
    --no-monitoring)
      INSTALL_MONITORING=false
      ;;
    [0-9]*)  # handled by NUM_WORKERS already
      ;;
    *)
      echo "❗ Unknown argument: $arg"
      echo "Usage: $0 [num_workers] [--no-host-setup] [--no-monitoring]"
      exit 1
      ;;
  esac
done

# Request sudo once so we don't have to ask further down
sudo -v

# Keep sudo session active throughout the script
while true; do sudo -v; sleep 60; done &

if [ "$CLEANUP" = true ]; then
  log "🧹 Cleaning up Kubernetes setup..."
  /bin/bash "$TEARDOWN_SCRIPT"  2>&1 | tee -a "$LOG_FILE"
  log "✅ All clean!"
  exit 0
fi

# ========== Host Setup ==========
if [ "$INSTALL_HOST_PREREQS" = true ]; then
  log "🛠️ Installing tools on host..."
  /bin/bash "$HOST_PRE_REQ_SCRIPT" 2>&1 | tee -a "$LOG_FILE"
else
  log "⚠️ Skipping host setup as per flag"
fi

# ========== Launch Containers ==========
log "🚀 Launching master container..."
sudo lxc launch "$IMAGE" "$MASTER_NAME" --profile "$PROFILE" >> "$LOG_FILE" 2>&1

for i in $(seq 1 "$NUM_WORKERS"); do
  WORKER_NAME="kubernetes-worker-$i"
  log "🚀 Launching worker container: $WORKER_NAME"
  sudo lxc launch "$IMAGE" "$WORKER_NAME" --profile "$PROFILE" >> "$LOG_FILE" 2>&1
done

# ========== Push Setup Files ==========
log "📦 Pushing install scripts to all nodes..."
sudo lxc file push "$NODE_PRE_REQ_SCRIPT" "$MASTER_NAME/install.sh"
sudo lxc file push "$MASTER_INIT_KUBERNETES_SCRIPT" "$MASTER_NAME/init.sh"
sudo lxc exec "$MASTER_NAME" -- mkdir /scripts
sudo lxc file push "$HELPERS_SCRIPT" "$MASTER_NAME/scripts/helpers.sh"

for i in $(seq 1 "$NUM_WORKERS"); do
  WORKER_NAME="kubernetes-worker-$i"
  sudo lxc file push "$NODE_PRE_REQ_SCRIPT" "$WORKER_NAME/install.sh"
  sudo lxc file push "$WORKER_NODE_CONNECT_TO_KUBERNETES_SCRIPT" "$WORKER_NAME/connect.sh"
  sudo lxc exec "$WORKER_NAME" -- mkdir /scripts
  sudo lxc file push "$HELPERS_SCRIPT" "$WORKER_NAME/scripts/helpers.sh"
done

# ========== Setup Master ==========
log "🔧 Installing Kubernetes on master..."
run_pre_req_setup "$MASTER_NAME"

log "📦 Running Kubernetes init on master..."
sudo lxc exec "$MASTER_NAME" -- /bin/bash /init.sh 2>&1 | tee -a "$LOG_FILE"

log "📁 Retrieving kubeconfig from master..."
mkdir -p ~/.kube
sudo lxc file pull "$MASTER_NAME/etc/kubernetes/admin.conf" ~/.kube/config

log "🔐 Retrieving cluster join script from master..."
sudo lxc file pull "$MASTER_NAME/joincluster.sh" joincluster.sh

log "📤 Distributing join script to worker nodes..."
for i in $(seq 1 "$NUM_WORKERS"); do
  WORKER_NAME="kubernetes-worker-$i"
  sudo lxc file push joincluster.sh "$WORKER_NAME/joincluster.sh"
done

# ========== Setup Workers ==========
log "🧩 Running pre-req setup on worker nodes..."
for i in $(seq 1 "$NUM_WORKERS"); do
  WORKER_NAME="kubernetes-worker-$i"
  run_pre_req_setup "$WORKER_NAME"
  log "🔗 Connecting $WORKER_NAME to cluster..."
  sudo lxc exec "$WORKER_NAME" -- /bin/bash /connect.sh >> "$LOG_FILE" 2>&1
done

log "✅ Kubernetes cluster setup complete with $NUM_WORKERS worker nodes."

# ========== Monitoring ==========
if [ "$INSTALL_MONITORING" = true ]; then
  log "📈 Installing monitoring stack (Prometheus + Grafana)..."
  /bin/bash "$INSTALL_TOOLS_SCRIPT"  2>&1 | tee -a "$LOG_FILE"
else
  log "⚠️ Skipping monitoring install as per flag"
fi

log "🎉 All done!"
