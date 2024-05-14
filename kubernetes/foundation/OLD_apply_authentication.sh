#!/bin/sh

#
# https://github.com/ory/k8s/releases/tag/v0.39.1
#
# Apache 2.0 license:
#
# https://github.com/ory/k8s/blob/v0.39.1/LICENSE
#
#
# Note: Until we get to the platform layer, we leave all authentication
# enabled as "anonymous".  When we deploy the platform layer, we deploy
# identity management and then turn off anonymous access.
# (Later we add authorization by identity, too.)
#

#
# Note that the Helm Chart.yaml tagged 0.39.1 shows "0.39.0" as the version.
# https://github.com/ory/k8s/blob/v0.39.1/helm/charts/oathkeeper/Chart.yaml
#
ORY_OATHKEEPER_VERSION=0.40.6
ORY_OATHKEEPER_HELM_CHART_VERSION=0.39.1

echo "Installing authentication (ory oathkeeper)..."

CLUSTER_DIR=/cloud-init/kubernetes/foundation/cluster
KUBECONFIG=$HOME/.kube/kubeconfig-kubedemo.yaml

echo "  Applying auth namespace:"
kubectl apply \
        --filename $CLUSTER_DIR/authentication-ory-oathkeeper-namespace.yaml \
        --kubeconfig $KUBECONFIG \
    || exit 1

#
# ory oathkeeper authentication:
#
echo "  Adding Ory Helm repo:"
helm repo add ory https://k8s.ory.sh/helm/charts \
    || exit 1

echo "  Kicking Helm:"
helm repo update \
     --kubeconfig $KUBECONFIG \
    || exit 1

#
# We cannot wait for Ory to spin up, because we have to wait until
# after the maester operator has deleted ConfigMap "oathkeeper-rules"
# before we re-deploy the ConfigMap, so that Oathkeeper Pod can start.
#
echo "  Installing Ory Oathkeeper Helm chart version $ORY_OATHKEEPER_HELM_CHART_VERSION:"
helm upgrade --install oathkeeper ory/oathkeeper \
     --version $ORY_OATHKEEPER_HELM_CHART_VERSION \
     --values $CLUSTER_DIR/authentication-ory-oathkeeper-values.yaml \
     --namespace auth \
     --kubeconfig $KUBECONFIG \
    || exit 1

#
# OMG Ory Oathkeeper Maester DELIBERATELY DELETES oathkeeper-rules ConfigMap.
# And if oathkeeper-rules doesn't exist then the Oathkeeper Pod never spins up.
# So we have to create a ConfigMap called "oathkeeper-rules"
# AFTER we deploy Ory.
# Dumbdumbdumbdumbdumb
#
echo "  Applying oOry Oathkeeper access rules ConfigMap:"
kubectl apply \
        --filename $CLUSTER_DIR/authentication-ory-oathkeeper-configmap.yaml \
        --kubeconfig $KUBECONFIG \
    || exit 1

echo "  Applying Istio JWT authentication (using Ory Oathkeeper) to gateway:"
kubectl apply \
        --filename $CLUSTER_DIR/authentication-istio-resources.yaml \
        --kubeconfig $KUBECONFIG \
    || exit 1

echo "SUCCESS Installing authentication (oathkeeper)."
exit 0
