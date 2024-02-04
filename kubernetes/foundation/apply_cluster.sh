#!/bin/sh

#
# Populates the "kubedemo" cluster with storage and so on.
#
echo "Applying foundational components to the \"kubedemo\" cluster..."

CLUSTER_DIR=/cloud-init/kubernetes/foundation/cluster
KUBECONFIG=$HOME/.kube/kubeconfig-kubedemo.yaml

echo "  Creating Rook/Ceph storage for \"kubedemo\" cluster:"
echo "    Installing Rook operator:"
kubectl apply \
        --filename $CLUSTER_DIR/storage-rook-crds.yaml \
        --filename $CLUSTER_DIR/storage-rook-common.yaml \
        --filename $CLUSTER_DIR/storage-rook-operator.yaml \
        --kubeconfig ~/.kube/kubeconfig-kubedemo.yaml \
    || exit 1

echo "    Creating Rook storage cluster:"
kubectl apply \
        --filename $CLUSTER_DIR/storage-rook-cluster.yaml \
        --kubeconfig ~/.kube/kubeconfig-kubedemo.yaml \
    || exit 1

echo "    Creating Rook CephBlockPool:"
kubectl apply \
        --filename $CLUSTER_DIR/storage-rook-blockpool.yaml \
        --filename $CLUSTER_DIR/storage-rook-storageclass.yaml \
        --kubeconfig ~/.kube/kubeconfig-kubedemo.yaml \
    || exit 1

echo "SUCCESS Applying foundational components to the \"kubedemo\" cluster."
exit 0
