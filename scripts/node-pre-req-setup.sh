sudo apt update && sudo apt upgrade -y
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update

sudo apt-get install -y kubelet kubeadm kubectl -y

sudo apt-mark hold kubelet kubeadm kubectl

# Needed to overcome an LXC issue I came acorss in which the kubelet wouldn't start in any of the LXC containers
sudo ln -s /dev/console /dev/kmsg

sudo systemctl enable --now kubelet

sudo swapoff -a

sudo systemctl enable kubelet

sudo apt install -y containerd

sudo systemctl enable containerd

sudo systemctl start containerd

## Another workaround for LXC that I needed to do .
mkdir -p  /etc/containerd/
containerd config default | tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
service containerd restart
service kubelet restart

## Only run these steps on Master
if [[ $(hostname) =~ .*master.* ]]
then

  # Initialize Kubernetes
  kubeadm init --pod-network-cidr=10.244.0.0/16 --ignore-preflight-errors=all >> /root/kubeinit.log 2>&1

  # Set up kubeconfig for master
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

  # Install flannel
  kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

  commandToJoin=$(kubeadm token create --print-join-command 2>/dev/null)
  echo "$commandToJoin --ignore-preflight-errors=all" > /joincluster.sh
fi

## Only run these on worker nodes

if [[ $(hostname) =~ .*worker.* ]]
then

  # Join worker nodes to the Kubernetes cluster
  #sshpass -p "kubeadmin" scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no kubernetes-master.lxd:/joincluster.sh /joincluster.sh 2>/tmp/joincluster.log
  bash /joincluster.sh >> /tmp/joincluster.log 2>&1

fi
