#!/bin/bash
export DEBIAN_FRONTEND=noninteractive

# ************* vars *************
TOKEN=b8982b.68123f577c6a71d3
NETWORK=CALICO
# ************* init *************

PUBLIC_MASTER_IP=`ifconfig eth0 | grep 'inet ' | cut -d: -f2 | awk '{print $2}'`
PRIVATE_MASTER_IP=`ifconfig eth1 | grep 'inet ' | cut -d: -f2 | awk '{print $2}'`

curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -

cat <<EOF > /etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF

curl https://get.docker.com/ >> install-docker.sh
chmod +x install-docker.sh
./install-docker.sh

apt-get update
apt-get install -y kubelet kubeadm kubectl kubernetes-cni


# ************* master specific *************
sed "s/ExecStart=\/usr\/bin\/kubelet.*/& --node-ip=$PRIVATE_MASTER_IP/" /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

systemctl daemon-reload
systemctl restart kubelet

if [ "$NETWORK" == "CALICO" ]
then
  kubeadm init --token $TOKEN --apiserver-advertise-address $PUBLIC_MASTER_IP --pod-network-cidr=192.168.0.0/16 >> kubeadm.log
elif [ "$NETWORK" == "FLANNEL" ]
then
  kubeadm init --token $TOKEN --apiserver-advertise-address $PUBLIC_MASTER_IP --pod-network-cidr=10.244.0.0/16  >> kubeadm.log
elif [ "$NETWORK" == "CANAL" ]
then
  kubeadm init --token $TOKEN --apiserver-advertise-address $PUBLIC_MASTER_IP --pod-network-cidr=10.244.0.0/16  >> kubeadm.log
fi

mkdir -p $HOME/.kube && sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config && sudo chown $(id -u):$(id -g) $HOME/.kube/config

if [ "$NETWORK" == "CALICO" ]
then
  IP_AUTODETECTION_METHOD=interface=eth1
  IP6_AUTODETECTION_METHOD=interface=eth1
  kubectl apply -f https://docs.projectcalico.org/v3.6/getting-started/kubernetes/installation/hosted/kubernetes-datastore/calico-networking/1.7/calico.yaml
elif [ "$NETWORK" == "FLANNEL" ]
then
  kubectl create -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml --namespace=kube-system
elif [ "$NETWORK" == "CANAL" ]
then
  kubectl apply -f https://docs.projectcalico.org/v3.0/getting-started/kubernetes/installation/hosted/canal/rbac.yaml
  kubectl apply -f https://docs.projectcalico.org/v3.0/getting-started/kubernetes/installation/hosted/canal/canal.yaml
fi

# ************* bonus stuff specific *************

# install dashboard to visualize cluster
# kubectl create -f https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/recommended/kubernetes-dashboard.yaml --namespace=kube-system
