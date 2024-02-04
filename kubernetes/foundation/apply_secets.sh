#!/bin/sh

#
# HashiCorp Vault for secrets management.
#
echo "Installing secrets (HashiCorp Vault)..."

CLUSTER_DIR=/cloud-init/kubernetes/foundation/cluster
KUBECONFIG=$HOME/.kube/kubeconfig-kubedemo.yaml

echo "  Adding HashiCorp Helm repo:"
helm repo add hashicorp https://helm.releases.hashicorp.com \
     --kubeconfig $KUBECONFIG \
    || exit 1

echo "  Creating namespace \"vault\":"
kubectl apply \
        --filename $CLUSTER_DIR/secrets-vault-namespace.yaml \
        --kubeconfig $KUBECONFIG \
    || exit 1

echo "  Helm installing HashiCorp Vault:"
helm install vault hashicorp/vault \
     --namespace vault \
     --kubeconfig $KUBECONFIG \
    || exit 1

echo "SUCCESS Installing secrets (HashiCorp Vault)."
exit 0

