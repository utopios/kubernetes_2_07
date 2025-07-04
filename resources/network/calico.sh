k3d cluster create mon-cluster \
  --k3s-arg "--flannel-backend=none@server:*" \
  --k3s-arg "--disable-network-policy@server:*"\
  --port "30080:30080@loadbalancer"
# Installer l'opérateur Calico
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/tigera-operator.yaml

# Configurer Calico
kubectl create -f - <<EOF
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  calicoNetwork:
    ipPools:
    - blockSize: 26
      cidr: 10.42.0.0/16
      encapsulation: VXLANCrossSubnet
      natOutgoing: Enabled
      nodeSelector: all()
EOF