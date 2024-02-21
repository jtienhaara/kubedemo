#!/bin/sh

#
# Turn on Prometheus metrics and add Grafana dashboards for various
# apps (storage, secrets, and so on).
#

echo "Integrating observability with apps..."

CLUSTER_DIR=/cloud-init/kubernetes/foundation/cluster
KUBECONFIG=$HOME/.kube/kubeconfig-kubedemo.yaml

echo "  Applying observability manifests for specific applications:"
for OBSERVABILITY_MANIFEST in \
     $CLUSTER_DIR/integration-prometheus-clusterrole.yaml \
     $CLUSTER_DIR/integration-prometheus-rook-ceph.yaml \
     $CLUSTER_DIR/integration-grafana-rook-ceph.yaml \
     $CLUSTER_DIR/integration-grafana-vault.yaml \
     $CLUSTER_DIR/integration-grafana-istio.yaml \
     $CLUSTER_DIR/integration-grafana-ory-oathkeeper.yaml
do
    echo "    $OBSERVABILITY_MANIFEST:"
    kubectl apply \
            --filename $OBSERVABILITY_MANIFEST \
            --kubeconfig $KUBECONFIG \
        || exit 1
done

echo "  Re-applying grafana deployment:"
kubectl apply \
        --filename $CLUSTER_DIR/observability/grafana-deployment.yaml \
        --kubeconfig $KUBECONFIG \
    || exit 1

echo "SUCCESS Integrating observability for apps."
exit 0
