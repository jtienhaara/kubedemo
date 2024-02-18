#!/bin/sh

CLUSTER_DIR=/cloud-init/kubernetes/foundation/cluster
KUBECONFIG=$HOME/.kube/kubeconfig-kubedemo.yaml

kubectl get secret rook-ceph-dashboard-password \
        --output jsonpath='{.data.password}' \
        --namespace rook-ceph \
        --kubeconfig $KUBECONFIG \
    | base64 -d \
    || exit 1

echo ""

exit 0
