#!/bin/sh

#
# HashiCorp Vault for secrets management.
#
# Version 0.25.0 of the Vault Helm chart (1.14.0 of Vault) is from:
#
#     https://github.com/hashicorp/vault-helm/releases
#
# WARNING: HashiCorp has changed many of their software systems to
# the non-open source MariaDB BSL license, including HashiCorp Vault
# 1.14.9 and up:
#
#     https://github.com/hashicorp/vault/pull/24390
#
# The Helm Chart used here is the last Helm Chart released with
# the open source version of HashiCorp Vault, version 1.14.0:
#
#     https://github.com/hashicorp/vault-helm/releases
#     https://github.com/hashicorp/vault-helm/releases/tag/v0.25.0
#
# Vault version 1.14.0 is not officially supported under
# Kubernetes 1.29 (only up to 1.27 is officially supported):
#
#     https://developer.hashicorp.com/vault/docs/v1.14.x/platform/k8s/vso#supported-kubernetes-versions
#
# More information about Vault 1.14.0:
#
#     https://github.com/hashicorp/vault/releases
#     https://github.com/hashicorp/vault/releases/tag/v1.14.0
#     https://github.com/hashicorp/vault/tree/v1.14.0
#
# IBM forked HashiCorp Vault and has begun creating OpenBao,
# but at the time of writing it is less than 2 months old, with
# no releases or binary packages, and even the Dockerfile still
# lists HashiCorp as the official maintainers, so it's not ready
# for us to demo yet:
#
#     https://github.com/openbao/openbao
#
# It was picked up in the aftermath of the Vault re-licensing in
# late 2023, when Vault 1.14.x was still under the MPL:
#
#     https://thenewstack.io/meet-openbao-an-open-source-fork-of-hashicorp-vault/
#
# The Kubernetes secrets store CSI driver 1.4.1 is available at:
#
#     https://github.com/kubernetes-sigs/secrets-store-csi-driver/releases
#     https://secrets-store-csi-driver.sigs.k8s.io/getting-started/installation.html
#     https://secrets-store-csi-driver.sigs.k8s.io/topics/best-practices
#     https://github.com/kubernetes-sigs/secrets-store-csi-driver/tree/main/charts/secrets-store-csi-driver#configuration
#
# HashiCorp Vault 1.14.0 is licensed under the Mozilla Public License 2.0:
#
#     https://github.com/hashicorp/vault/blob/v1.14.0/LICENSE
#
# The Vault Helm chart is licensed under the Mozilla Public License 2.0:
#
#     https://github.com/hashicorp/vault-helm/blob/v0.25.0/LICENSE
#
# The Vault CSI Provider version 1.4.1 is the last version released
# under the Mozilla Public License 2.0:
#
#     https://github.com/hashicorp/vault-csi-provider/blob/v1.4.1/LICENSE
#
# The Kubernetes secrets store CSI driver is licensed under the Apache 2.0
# license:
#
#     https://github.com/kubernetes-sigs/secrets-store-csi-driver/blob/v1.4.1/LICENSE
#
VAULT_HELM_VERSION=0.25.0
VAULT_VERSION=1.14.0
VAULT_CSI_VERSION=1.4.1

CSI_DRIVER_HELM_VERSION=1.4.1

echo "Installing secrets (HashiCorp Vault)..."

CLUSTER_DIR=/cloud-init/kubernetes/foundation/cluster
KUBECONFIG=$HOME/.kube/kubeconfig-kubedemo.yaml

echo "  Adding secrets store CSI driver Helm repo:"
helm repo add secrets-store-csi-driver \
     https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts \
     --kubeconfig $KUBECONFIG \
    || exit 1

echo "  Helm installing secrets store CSI driver:"
helm upgrade --install csi-secrets-store \
     secrets-store-csi-driver/secrets-store-csi-driver \
     --version $CSI_DRIVER_HELM_VERSION \
     --namespace kube-system \
     --kubeconfig $KUBECONFIG \
    || exit 1

echo "  Adding HashiCorp Helm repo:"
helm repo add hashicorp \
     https://helm.releases.hashicorp.com \
     --kubeconfig $KUBECONFIG \
    || exit 1

echo "  Creating namespace \"vault\":"
kubectl apply \
        --filename $CLUSTER_DIR/secrets-vault-namespace.yaml \
        --kubeconfig $KUBECONFIG \
    || exit 1

echo "  Helm installing HashiCorp Vault:"
helm upgrade --install vault hashicorp/vault \
     --version $VAULT_HELM_VERSION \
     --values $CLUSTER_DIR/secrets-vault-values.yaml \
     --namespace vault \
     --kubeconfig $KUBECONFIG \
    || exit 1

#
# Now initialize Vault:
#
#     https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-raft-deployment-guide#initialize-and-unseal-vault
#

echo "SUCCESS Installing secrets (HashiCorp Vault)."
exit 0

