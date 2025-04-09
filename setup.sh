#!/bin/bash

# Usage: ./setup-k8s.sh <number_of_workers>
NUM_WORKERS=${1:-2}  # Default to 2 if not provided
PROFILE="k8s"
IMAGE="ubuntu:24.04"
MASTER_NAME="kubernetes-master"
HOST_PRE_REQ_SCRIPT="scripts/host-pre-req-setup.sh"
NODE_PRE_REQ_SCRIPT="scripts/node-pre-req-setup.sh"
MASTER_INIT_KUBERNETES_SCRIPT="scripts/master-setup-kubernetes.sh"
WORKER_NODE_CONNECT_TO_KUBERNETES_SCRIPT="scripts/worker-node-connect-to-kubernetes.sh"

# Function to run the pre-requisite setup on a container
run_pre_req_setup() {
  NODE_NAME=$1
  echo "Running pre-req setup on $NODE_NAME..."
  sudo lxc exec $NODE_NAME -- /bin/bash /install.sh
}

echo "Installing tools on host"
/bin/bash $HOST_PRE_REQ_SCRIPT

# Create master
echo "Launching master container..."
sudo lxc launch $IMAGE $MASTER_NAME --profile $PROFILE

# Create worker nodes
for i in $(seq 1 $NUM_WORKERS); do
  WORKER_NAME="kubernetes-worker-$i"
  echo "Launching worker node: $WORKER_NAME..."
  sudo lxc launch $IMAGE $WORKER_NAME --profile $PROFILE
done

echo "Pushing install files to all nodes..."
sudo lxc file push NODE_PRE_REQ_SCRIPT $MASTER_NAME/install.sh
sudo lxc file push MASTER_INIT_KUBERNETES_SCRIPT $MASTER_NAME/kubernetes-init.sh
for i in $(seq 1 $NUM_WORKERS); do
  WORKER_NAME="kubernetes-worker-$i"
  sudo lxc file push NODE_PRE_REQ_SCRIPT $WORKER_NAME/install.sh
  sudo lxc file push WORKER_NODE_CONNECT_TO_KUBERNETES_SCRIPT $WORKER_NAME/connect.sh
done

# Run pre-req setup on master and worker nodes
echo "Running install.sh on master node..."
run_pre_req_setup $MASTER_NAME

echo "Running K8s init on master node..."
sudo lxc exec $MASTER_NAME -- /bin/bash /init.sh

echo "Retrieving kubeconfig from master..."
mkdir -p ~/.kube
sudo lxc file pull $MASTER_NAME/etc/kubernetes/admin.conf ~/.kube/config

echo "Retrieving cluster join script..."
sudo lxc file pull $MASTER_NAME/joincluster.sh joincluster.sh

echo "Distributing join script to workers..."
for i in $(seq 1 $NUM_WORKERS); do
  WORKER_NAME="kubernetes-worker-$i"
  sudo lxc file push joincluster.sh $WORKER_NAME/joincluster.sh
done

# Run pre-req setup on worker nodes
echo "Running install.sh on worker nodes..."
for i in $(seq 1 $NUM_WORKERS); do
  WORKER_NAME="kubernetes-worker-$i"
  run_pre_req_setup $WORKER_NAME
  echo "Connecting $WORKER_NAME to Cluster"
  sudo lxc exec $WORKER_NAME -- /bin/bash /connect.sh
done

echo "✅ Kubernetes cluster setup is complete with $NUM_WORKERS worker nodes."

# Install Monitoring
echo "Installing Monitoring..."

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

kubectl create namespace monitoring
helm install prometheus prometheus-community/kube-prometheus-stack --namespace monitoring
