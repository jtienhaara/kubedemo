#!/bin/sh

#
# gitea for git version control and related project management
# web features (issues, etc).
#
# Version 1.21.6 from:
#
#     https://github.com/go-gitea/gitea/tree/v1.21.6
#
# Licensed under the MIT license:
#
#     https://github.com/go-gitea/gitea/blob/v1.21.6/LICENSE
#

GITEA_VERSION=1.21.6
GITEA_HELM_CHART_VERSION=10.1.2

echo "Installing git (Gitea $GITEA_VERSION)..."

CLUSTER_DIR=/cloud-init/kubernetes/platform/cluster
KUBECONFIG=$HOME/.kube/kubeconfig-kubedemo.yaml

echo "  Creating gitea PostgreSQL database:"
kubectl apply \
        --filename $CLUSTER_DIR/git-postgres-database.yaml \
        --kubeconfig $KUBECONFIG \
    || exit 1

echo "  Waiting for gitea PostgreSQL database Job to finish:"
kubectl wait \
	--for jsonpath='{.status.succeeded}'=1 \
	--all Job \
	--namespace db \
        --kubeconfig $KUBECONFIG \
    || exit 1

echo "  Creating gitea Namespace:"
kubectl apply \
        --filename $CLUSTER_DIR/git-gitea-namespace.yaml \
        --kubeconfig $KUBECONFIG \
    || exit 1

echo "  Applying gitea configuration Secret:"
kubectl apply \
        --filename $CLUSTER_DIR/git-gitea-config.yaml \
        --kubeconfig $KUBECONFIG \
    || exit 1

#
# Gitea Kubernetes install:
#
#     https://docs.gitea.com/installation/install-on-kubernetes
#
# Gitea Helm Chart version 10.1.2:
#
#     https://gitea.com/gitea/helm-chart/releases/tag/v10.1.2
#
helm repo add gitea-charts \
     https://dl.gitea.com/charts/ \
     --kubeconfig $KUBECONFIG \
    || exit 1

helm install gitea 
helm upgrade --install gitea \
     gitea-charts/gitea \
     --version $GITEA_HELM_CHART_VERSION \
     --values $CLUSTER_DIR/git-gitea-values.yaml \
     --namespace gitea \
     --wait \
     --kubeconfig $KUBECONFIG \
    || exit 1

echo "SUCCESS Installing git (Gitea $GITEA_VERSION)."
exit 0
