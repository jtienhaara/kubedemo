#!/bin/sh

#
# Creates the "kubedemo" cluster, which hosts git server, chat, etc.
#
echo "Creating \"kubedemo\" cluster..."

CLUSTER_DIR=/cloud-init/kubernetes/foundation/cluster

echo "  Ensuring ~/.kube directory:"
mkdir -p ~/.kube \
    || exit 1

echo "  Increasing ulimit / NOFILES to 65536 for kind / Docker:"
sudo sed -i.ORIGINAL \
     's|^#DefaultLimitNOFILE=.*$|DefaultLimitNOFILE=65536:524288|' \
     /etc/systemd/system.conf \
    || exit 1
ulimit -n 65536 \
    || exit 1

echo "  Creating \"kubedemo\" kind cluster (~/.kube/kubeconfig-kubedemo.yaml):"
kind create cluster \
     --config $CLUSTER_DIR/cluster-kind.yaml \
     --kubeconfig ~/.kube/kubeconfig-kubedemo.yaml
EXIT_CODE=$?
if test $EXIT_CODE -ne 0
then
    # kind frequently fails on the first try inside this VM.  :(
    echo "    Retrying to create \"kubedemo\" kind cluster (~/.kube/kubeconfig-kubedemo.yaml):"
    kind create cluster \
         --config $CLUSTER_DIR/cluster-kind.yaml \
         --kubeconfig ~/.kube/kubeconfig-kubedemo.yaml \
        || exit 1
fi

echo "  Creating Rook/Ceph storage for \"kubedemo\" cluster:"
echo "    Installing Rook operator:"
kubectl apply \
        --filename $CLUSTER_DIR/storage-rook-crds.yaml \
        --filename $CLUSTER_DIR/storage-rook-common.yaml \
        --filename $CLUSTER_DIR/storage-rook-operator.yaml \
        --kubeconfig ~/.kube/kubeconfig-kubedemo.yaml

echo "    Creating Rook storage cluster:"
kubectl apply \
        --filename $CLUSTER_DIR/storage-rook-cluster.yaml \
        --kubeconfig ~/.kube/kubeconfig-kubedemo.yaml

echo "    Creating Rook CephBlockPool:"
kubectl apply \
        --filename $CLUSTER_DIR/storage-rook-blockpool.yaml \
        --filename $CLUSTER_DIR/storage-rook-storageclass.yaml \
        --kubeconfig ~/.kube/kubeconfig-kubedemo.yaml

echo "SUCCESS Creating \"kubedemo\" cluster..."
exit 0
