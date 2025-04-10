# Kubernetes On LXC


This project automates the setup of a Kubernetes cluster using LXC (Linux Containers) and kubeadm. It consists of multiple scripts designed to deploy a multi-node Kubernetes environment with both master and worker nodes.

The scripts ensure the nodes are set up with all necessary prerequisites, the Kubernetes components are installed, and the cluster is initialized. It’s intended for users looking to set up a Kubernetes environment on a local machine using LXC containers for the nodes.

#### Why not use Kind / MiniKube / K3d
I would **absolutely** recommend you use any of those above tools. This project is just an experiment I ran for myself for seeing the viability of deploying a cluster on LXC and any limitations I might face. If you're looking to spin up a non-production quality cluster, that runs in LXC, then this is a tool for you!

## Notice

This is heavily geared towards a Ubuntu 24.x installation for host, as such the host commands are either 'apt' or 'snap'. I ran this on a fresh **Ubuntu Server version 24.04.02 LTS**.

## Features

- Setup Kubernetes cluster with a master and multiple worker nodes.
- Install required dependencies (e.g., `kubectl`, `kubeadm`, `helm`, etc.).
- Optionally install monitoring tools (Prometheus and Grafana).
- Optionally clean up the Kubernetes setup (stop and delete containers).
---
## Example
```bash
 ./setup.sh -p 1
2025-04-10 12:22:44 | 🛠️ Installing tools on host...
2025-04-10 12:22:44 |   📝 Logging output to ./logs/host-pre-req-setup-20250410-122244.log
2025-04-10 12:22:44 |   🚀 Installing LXD...
2025-04-10 12:22:44 |   ⚙️ Preseeding LXD config...
2025-04-10 12:22:44 |   📦 Creating LXD profile 'k8s'...
2025-04-10 12:22:44 |   📤 Applying k8s profile config...
2025-04-10 12:22:45 |   🔄 Updating system packages...
2025-04-10 12:22:54 |   📥 Installing Kubernetes and Helm prerequisites...
2025-04-10 12:22:54 |   📂 Adding Kubernetes APT repo...
2025-04-10 12:22:54 |   🔄 Updating package index again...
2025-04-10 12:23:02 |   📦 Installing Helm and kubectl...
2025-04-10 12:23:03 | ✅ Host setup complete!
2025-04-10 12:23:03 | 🚀 Launching master container...
2025-04-10 12:23:07 | 🚀 Launching worker container: kubernetes-worker-1
2025-04-10 12:23:14 | 📦 Pushing install scripts to all nodes...
2025-04-10 12:23:15 | 🔧 Installing Kubernetes on master...
2025-04-10 12:23:15 | 🔧 Running pre-req setup on kubernetes-master...
2025-04-10 12:23:15 |   🔧 Starting Kubernetes installation...
2025-04-10 12:24:07 |           ✅ Kubernetes installation is complete!
2025-04-10 12:24:07 | 📦 Running Kubernetes init on master...
2025-04-10 12:24:07 |   🔧 Starting Kubernetes initialization...
2025-04-10 12:24:49 |           ✅ Kubernetes initialization is complete!
2025-04-10 12:24:49 | 📁 Retrieving kubeconfig from master...
2025-04-10 12:24:49 | 🔐 Retrieving cluster join script from master...
2025-04-10 12:24:49 | 📤 Distributing join script to worker nodes...
2025-04-10 12:24:49 | 🧩 Running pre-req setup on worker nodes...
2025-04-10 12:24:49 | 🔧 Running pre-req setup on kubernetes-worker-1...
2025-04-10 12:24:49 |   🔧 Starting Kubernetes installation...
2025-04-10 12:25:39 |           ✅ Kubernetes installation is complete!
2025-04-10 12:25:39 | 🔗 Connecting kubernetes-worker-1 to cluster...
2025-04-10 12:25:40 | ✅ Kubernetes cluster setup complete with 1 worker nodes.
2025-04-10 12:25:40 | 📈 Installing monitoring stack (Prometheus + Grafana)...
2025-04-10 12:25:41 |   📁 Creating 'monitoring' namespace...
2025-04-10 12:26:20 |   ✅ Monitoring Stack Deployed
2025-04-10 12:26:20 | 🎉 All done!
```
---
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
```
---
## Prerequisites

- Ubuntu 20.04 or later (for the host machine).
- Sudo access on the host machine for script execution.

### Network Configuration for Bridging

In order to enable proper network communication between the LXC containers, you'll need to set up a network bridge on the host machine. This can be done by updating the `/etc/netplan/01-netcfg.yaml` file.

Follow these steps to configure the network bridge:

1. Edit the `/etc/netplan/01-netcfg.yaml` file:

    ```bash
    sudo vi /etc/netplan/01-netcfg.yaml
    ```

2. Update the file to contain the following configuration:

    ```yaml
    network:
      version: 2
      renderer: networkd
      ethernets:
        eno1:
          dhcp4: no
      bridges:
        br0:
          interfaces: [eno1]
          dhcp4: yes
    ```

    - Replace `eno1` with your actual network interface name, if it's different (you can check this with `ip link`).
    - This configuration creates a bridge (`br0`) and attaches it to the `eno1` interface.

3. Apply the netplan configuration to bring up the network bridge:

    ```bash
    sudo netplan apply
    ```

After applying this configuration, your host will have a network bridge that allows the containers to communicate on the same network as the host.

**Note:**
>If you changed the network interface name from `eno1` to something else, you will also need to update the interface name in the `scripts/k8s-lxc-profile` file to match the new name.
---

## Installation and Setup

### Step 1: Clone the Repository

```bash
git clone <repository-url>
cd <repository-directory>
```
### Step 2 : Run script
```bash
./setup.sh

or 

./setup.sh --num-workers 3 # bring up 3 workers instead of the default 2
```
Run the setup.sh script to bring up the Kubernetes cluster. This script will:

- Install Kubernetes components (kubeadm, kubectl, kubelet).

- Configure cgroups and networking for Kubernetes.

- Initialize the Kubernetes master node with kubeadm init.

- Join worker nodes to the cluster using kubeadm join.

- Deploy a monitoring namespace that deploys Promethuis via helm.

### Step 3 : Check Deployment
```bash
kubectl get nodes
```

### Step 4 : Port Forward Promethius
```bash
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090"

kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-grafana 3000:80"

```

### Step 5 : Teardown / Cleanup
```bash
./setup.sh --cleanup
```

---

## Troubleshooting
If there are any issues during deployment then check the logs,  there will be a `logs` directory created during `setup`

---

## Directory Structure
The project contains the following files and directories:

- `setup.sh`: The main script that orchestrates the Kubernetes setup. It determines if the node is a master or a worker and runs the necessary steps accordingly.

- `scripts/host-pre-req-setup.sh`: Installs LXD and other prerequisites on the host machine.

- `scripts/node-pre-req-setup.sh`: Prepares the LXC containers to be used as Kubernetes nodes.

- `scripts/master-setup-kubernetes.sh`: Handles the setup of the master node, including kubeadm init and networking setup.

- `scripts/worker-node-connect-to-kubernetes.sh`: Joins the worker nodes to the Kubernetes cluster using kubeadm join.

- `helpers.sh`: Contains helper functions for formatting logs and organizing the setup process.

- `scripts/k8s-lxc-profile`: An LXD profile for containing our K8s LXC containers. Defaults to 2 CPU cores and 2GB memory.

## Future Improvements
- Extend Host OS support: at the moment I only built this in mind for Ubuntu 24.x distros. I plan to extend for Centos, Redhat, etc.

- Advanced Networking: Add support for advanced networking solutions like Calico or Weave for better multi-node networking.

- Kubernetes Versions: Add functionality to support different Kubernetes versions.

- Monitoring Tools: Integrate monitoring tools such as Prometheus and Grafana into the setup.

- Error Handling: Improve error handling and logging for easier troubleshooting.

- Better logging: At the moment there are too many logs shot out.
