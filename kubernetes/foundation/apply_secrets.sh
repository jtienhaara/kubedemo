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
     --wait \
     --kubeconfig $KUBECONFIG \
    || exit 1

echo "  Creating namespace \"vault\":"
kubectl apply \
        --filename $CLUSTER_DIR/secrets-vault-namespace.yaml \
        --kubeconfig $KUBECONFIG \
    || exit 1

echo "  Creating Certificate and Secret \"vault-tls\":"
kubectl apply \
        --filename $CLUSTER_DIR/secrets-vault-tls.yaml \
        --kubeconfig $KUBECONFIG \
    || exit 1

echo "  Adding HashiCorp Helm repo:"
helm repo add hashicorp \
     https://helm.releases.hashicorp.com \
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
# Wait for vault-0, vault-1 and vault-2 Pods to be running.
# Note: the Pods will not be Ready until we unseal Vault.
# So we use status.phase=Running as our condition instead.
#
echo "  Waiting for vault-0, vault-1 and vault-2 Pods to be Running:"
kubectl wait pod \
        --selector 'app.kubernetes.io/name=vault' \
	--for jsonpath='{.status.phase}'=Running \
        --timeout 120s \
	--namespace vault \
        --kubeconfig $KUBECONFIG \
    || exit 1

#
# Now initialize Vault:
#
#     https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-raft-deployment-guide#initialize-and-unseal-vault
#
# UNSEALED_VAULT should look something along the lines of:
#
#     Unseal Key 1: MBFSDepD9E6whREc6Dj+k3pMaKJ6cCnCUWcySJQymObb
#     Unseal Key 2: zQj4v22k9ixegS+94HJwmIaWLBL3nZHe1i+b/wHz25fr
#     Unseal Key 3: 7dbPPeeGGW3SmeBFFo04peCKkXFuuyKc8b2DuntA4VU5
#     Unseal Key 4: tLt+ME7Z7hYUATfWnuQdfCEgnKA2L173dptAwfmenCdf
#     Unseal Key 5: vYt9bxLr0+OzJ8m7c7cNMFj7nvdLljj0xWRbpLezFAI9
#
#     Initial Root Token: s.zJNwZlRrqISjyBHFMiEca6GF
#
# Note that checking vault operator init -status is needed in case
# we try to run this script again (aiming for idempotency).
# We should maybe error out if exit code is 1, and only unseal if
# exit code is 2, but for now we try to unseal in either case.
#
# From vault operator init --help:
#
#       -status
#           Print the current initialization status. An exit code of 0 means the
#           Vault is already initialized. An exit code of 1 means an error occurred.
#           An exit code of 2 means the Vault is not initialized. The default is
#           false.
#
echo "  Checking whether Vault has already been initialized:"
kubectl exec \
    vault-0 --namespace vault --kubeconfig $KUBECONFIG -- \
    vault operator init \
        -ca-cert /opt/vault/tls/vault-0/ca.crt \
        -non-interactive \
        -status
EXIT_CODE=$?
if test $EXIT_CODE -ne 0
then
    echo "  Unsealing Vault:"
    UNSEALED_VAULT=`kubectl exec \
                        vault-0 --namespace vault --kubeconfig $KUBECONFIG -- \
                        vault operator init \
                            -ca-cert /opt/vault/tls/vault-0/ca.crt \
                            -non-interactive`
    EXIT_CODE=$?
    if test $EXIT_CODE -ne 0
    then
        echo "ERROR Could not initialize vault-0" >&2
        exit 1
    fi

    echo "  Storing Vault unseal keys and initial root token in $HOME/.vault_keys:"
    touch $HOME/.vault_keys \
        || exit 1
    echo "$UNSEALED_VAULT" \
         > $HOME/.vault_keys \
        || exit 1
    chmod u-wx,go-rwx $HOME/.vault_keys \
        || exit 1
else
    UNSEALED_VAULT=`cat $HOME/.vault_keys`
    if test -z "$UNSEALED_VAULT"
    then
        echo "ERROR Vault has already been initialized, but there is no $HOME/.vault_keys to unseal it." >&2
        exit 1
    fi
fi

echo "  Unsealing vault Pods..."
UNSEAL_KEYS=`echo "$UNSEALED_VAULT" \
                 | grep '^Unseal Key [1-9][0-9]*:' \
                 | sed 's|^Unseal Key [1-9][0-9]*:[ ]*\(.*\)$|\1|'`
if test -z "$UNSEAL_KEYS"
then
    echo "ERROR Could not determine the unseal keys from $HOME/.vault_keys" >&2
    exit 1
fi

for VAULT_POD in vault-0 vault-1 vault-2
do
    UNSEAL_KEY_NUM=0
    IS_READY=false
    for UNSEAL_KEY in $UNSEAL_KEYS
    do
        NEW_UNSEAL_KEY_NUM=`expr $UNSEAL_KEY_NUM + 1`
        UNSEAL_KEY_NUM=$NEW_UNSEAL_KEY_NUM

        echo "    Unsealing $VAULT_POD with unseal key $UNSEAL_KEY_NUM:"
        kubectl exec \
                "$VAULT_POD" --namespace vault --kubeconfig $KUBECONFIG -- \
                vault operator unseal \
                    -ca-cert /opt/vault/tls/$VAULT_POD/ca.crt \
                    -non-interactive \
                    "$UNSEAL_KEY" \
            || exit 1

        if test $UNSEAL_KEY_NUM -ge 3
        then
            echo "      Waiting up to 3 seconds to see if $VAULT_POD is ready:"
            kubectl wait pod/$VAULT_POD \
	            --for condition=Ready \
                    --timeout 3s \
	            --namespace vault \
                    --kubeconfig $KUBECONFIG \
                    2> /dev/null
            if test $? -eq 0
            then
                echo "      $VAULT_POD is now ready."
                IS_READY=true
                break
            fi
        fi
    done

    if test "$IS_READY" != "true"
    then
        echo "      Waiting up to 3 seconds to see if $VAULT_POD is ready:"
        kubectl wait pod/$VAULT_POD \
	        --for condition=Ready \
                --timeout 3s \
	        --namespace vault \
                --kubeconfig $KUBECONFIG \
                2> /dev/null
        if test $? -eq 0
        then
            echo "      $VAULT_POD is now ready."
            IS_READY=true
        fi
    fi

    if test "$IS_READY" != "true"
    then
        echo "ERROR $VAULT_POD is still not ready after unsealing $UNSEAL_KEY_NUM keys" >&2
        exit 1
    fi
done

echo "SUCCESS Installing secrets (HashiCorp Vault)."
exit 0

