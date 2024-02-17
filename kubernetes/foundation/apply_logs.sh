#!/bin/sh

#
# Grafana Loki for log aggregation.
#
#     https://grafana.com/docs/loki/latest/setup/install/helm/install-scalable/
#     https://github.com/grafana/loki/releases/tag/v2.9.4
#
# Licensed under the Gnu Affero Public License v.3:
#
#     https://github.com/grafana/loki/blob/v2.9.4/LICENSE
#
# With some of the included components licensed under Apache 2.0:
#
#     https://github.com/grafana/loki/blob/v2.9.4/LICENSING.md
#

LOKI_VERSION=2.9.4

echo "Installing logs (Grafana Loki v$LOKI_VERSION)..."

CLUSTER_DIR=/cloud-init/kubernetes/foundation/cluster
KUBECONFIG=$HOME/.kube/kubeconfig-kubedemo.yaml

echo "  Creating logs namespace for Grafana Loki log aggregation:"
kubectl apply \
        --filename $CLUSTER_DIR/logs-loki-namespace.yaml \
        --kubeconfig $KUBECONFIG \
    || exit 1

#
# Rook/Ceph S3 object storage based on:
#
#     https://rook.io/docs/rook/v1.13/Storage-Configuration/Object-Storage-RGW/object-storage/#client-connections
#
echo "  Creating object bucket for Grafana Loki logs:"
kubectl apply \
        --filename $CLUSTER_DIR/logs-loki-storage.yaml \
        --kubeconfig $KUBECONFIG \
    || exit 1

echo "  Adding Grafana Loki Helm repo:"
helm repo add grafana \
     https://grafana.github.io/helm-charts \
     --kubeconfig $KUBECONFIG \
    || exit 1

echo "  Kicking Helm:"
helm repo update \
     --kubeconfig $KUBECONFIG \
    || exit 1

echo "  Helm installing Grafana Loki:"
helm upgrade --install loki \
     grafana/loki \
     --version $LOKI_VERSION \
     --values $CLUSTER_DIR/logs-loki-values.yaml \
     --namespace logs \
     --wait \
     --kubeconfig $KUBECONFIG \
    || exit 1

echo "SUCCESS Installing logs (Grafana Loki v$LOKI_VERSION)."
exit 0
