#!/bin/bash

# Source the helpers script which contians the log func
source "scripts/helpers.sh"

set -euo pipefail

LOG_DIR="./logs"
LOG_FILE="${LOG_DIR}/monitoring-install-$(date +%Y%m%d-%H%M%S).log"

mkdir -p "$LOG_DIR"
echo "📝 Logging output to $LOG_FILE"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "🔍 Installing monitoring stack with Prometheus and Grafana..."

# Ensure helm is installed
if ! command -v helm &>/dev/null; then
  echo "❌ Helm is not installed. Please install Helm before continuing."
  exit 1
fi

# Ensure kubectl is installed
if ! command -v kubectl &>/dev/null; then
  echo "❌ kubectl is not installed. Please install kubectl before continuing."
  exit 1
fi

# Add Helm repo if not already added
if ! helm repo list | grep -q "prometheus-community"; then
  echo "➕ Adding prometheus-community Helm repo..."
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
else
  echo "✅ Helm repo 'prometheus-community' already exists. Skipping..."
fi

echo "🔄 Updating Helm repositories..."
helm repo update

# Create namespace if it doesn't exist
if ! kubectl get namespace monitoring &>/dev/null; then
  echo "📁 Creating 'monitoring' namespace..."
  kubectl create namespace monitoring
else
  echo "ℹ️ Namespace 'monitoring' already exists. Skipping..."
fi

# Install or upgrade Prometheus stack
# Output success message
echo "✅ Monitoring Stack Deployed"

# Provide user with the port-forward commands to execute
echo ""
echo "🔧 To expose Prometheus and Grafana locally, run the following commands:"
echo "1. Port-forward Prometheus to localhost (9090):"
echo "   kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090"
echo ""
echo "2. Port-forward Grafana to localhost (3000):"
echo "   kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-grafana 3000:80"
echo ""
echo "⚡ After running these commands, Prometheus will be accessible at http://localhost:9090"
echo "⚡ Grafana will be accessible at http://localhost:3000 (default login: admin/admin)"
echo ""