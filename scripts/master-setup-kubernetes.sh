
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