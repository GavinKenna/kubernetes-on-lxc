# Kubernetes Setup Script

This script automates the setup of a Kubernetes cluster using LXC containers. It installs necessary tools, sets up the Kubernetes master and worker nodes, and optionally installs monitoring tools.

## Notice

This is heavily geared towards a Ubuntu 24.x installation for host, as such the host commands are either 'apt' or 'snap'

## Features

- Setup Kubernetes cluster with a master and multiple worker nodes.
- Install required dependencies (e.g., `kubectl`, `kubeadm`, `helm`, etc.).
- Optionally install monitoring tools (Prometheus and Grafana).
- Optionally clean up the Kubernetes setup (stop and delete containers).

## Usage

```bash
Usage: ./setup.sh [OPTIONS]

This script sets up a Kubernetes cluster with LXC containers as nodes and installs required tools.

Options:
  -h, --help          Show this help message and exit.
  -p, --num-workers   Number of worker nodes (default: 2).
  -i, --install-tools Install necessary tools on the host.
  -m, --monitoring     Install monitoring stack with Prometheus and Grafana (default: true).
  -c, --cleanup        Clean up Kubernetes setup (stop and delete containers).