#!/bin/sh

#
# https://github.com/ory/k8s/releases/tag/v0.39.1
#
# Apache 2.0 license:
#
# https://github.com/ory/k8s/blob/v0.39.1/LICENSE
#

#
# Note that the Helm Chart.yaml tagged 0.39.1 shows "0.39.0" as the version.
# https://github.com/ory/k8s/blob/v0.39.1/helm/charts/kratos/Chart.yaml
#
ORY_KRATOS_VERSION=1.0.0
ORY_KRATOS_HELM_CHART_VERSION=0.39.1

# TODO Do we want/need OIDC for Istio External Authorization?
# https://istio.io/latest/docs/tasks/security/authorization/authz-custom/
# (ory hydra)

echo "Installing identity management (ory kratos)..."

CLUSTER_DIR=/cloud-init/kubernetes/platform/cluster
KUBECONFIG=$HOME/.kube/kubeconfig-kubedemo.yaml

#
# ory kratos identity management:
#
echo "  Adding Ory Helm repo:"
helm repo add ory https://k8s.ory.sh/helm/charts \
    || exit 1

echo "  Kicking Helm:"
helm repo update \
     --kubeconfig $KUBECONFIG \
    || exit 1

echo "  Installing ory kratos Helm chart version $ORY_KRATOS_HELM_CHART_VERSION:"
helm upgrade --install kratos ory/kratos \
     --version $ORY_KRATOS_HELM_CHART_VERSION \
     --values $CLUSTER_DIR/identity-ory-kratos-values.yaml \
     --wait \
     --kubeconfig $KUBECONFIG \
    || exit 1

echo "SUCCESS Installing identity management (ory kratos)."
exit 0
