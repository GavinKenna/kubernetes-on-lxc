#!/bin/bash

# Source the helpers script which contians the log func
source "scripts/helpers.sh"

set -euo pipefail

LOG_DIR="./logs"
LOG_FILE="${LOG_DIR}/monitoring-install-$(date +%Y%m%d-%H%M%S).log"

mkdir -p "$LOG_DIR"
log "\t📝 Logging output to $LOG_FILE"

exec > >(tee -a "$LOG_FILE") 2>&1

log "\t🔍 Installing monitoring stack with Prometheus and Grafana..."

# Ensure helm is installed
if ! command -v helm &>/dev/null; then
  log "\t❌ Helm is not installed. Please install Helm before continuing."
  exit 1
fi

# Ensure kubectl is installed
if ! command -v kubectl &>/dev/null; then
  log "\t❌ kubectl is not installed. Please install kubectl before continuing."
  exit 1
fi

# Add Helm repo if not already added
if ! helm repo list | grep -q "prometheus-community"; then
  log "\t➕ Adding prometheus-community Helm repo..."
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
else
  log "\t\t✅ Helm repo 'prometheus-community' already exists. Skipping..."
fi

log "\t🔄 Updating Helm repositories..."
helm repo update

# Create namespace if it doesn't exist
if ! kubectl get namespace monitoring &>/dev/null; then
  log "\t📁 Creating 'monitoring' namespace..."
  kubectl create namespace monitoring
else
  log "\t\tℹ️ Namespace 'monitoring' already exists. Skipping..."
fi

# Deploy promethius
if ! helm install prometheus prometheus-community/kube-prometheus-stack --namespace monitoring >> "$LOG_FILE" 2>&1; then
  log_error "\t\t\t❌ Failed to deploy Prometheus."
  exit 1
fi

# Install or upgrade Prometheus stack
# Output success message
log "\t✅ Monitoring Stack Deployed"

# Provide user with the port-forward commands to execute
log ""
log "🔧 To expose Prometheus and Grafana locally, run the following commands:"
log "1. Port-forward Prometheus to localhost (9090):"
log "   kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090"
log ""
log "2. Port-forward Grafana to localhost (3000):"
log "   kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-grafana 3000:80"
log ""
log "⚡ After running these commands, Prometheus will be accessible at http://localhost:9090"
log "⚡ Grafana will be accessible at http://localhost:3000 (default login: admin/admin)"
log ""