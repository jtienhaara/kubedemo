#!/bin/sh

#
# HashiCorp Vault for secrets management.
#
# We also store out-of-cluster secrets (like the root token generated
# by Vault) in SOPS with AGE encryption.  The way we do it here is
# automated and completely insecure (putting the AGE private key itself
# in a plain text file), but the idea is to demonstrate layers of
# security without resorting to an external password manager (BitWarden
# or etc).
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

RUN_DIR=`dirname $0`

if test ! -x "$RUN_DIR/sops_run.sh"
then
    echo "ERROR sops_run.sh is required for $0, but is either missing or not executable: $RUN_DIR/sops_run.sh" >&2
    exit 1
fi

AGE_KEYS_FILE=$HOME/age-keys.env
if test ! -f "$AGE_KEYS_FILE"
then
    echo "  Creating AGE public and private encryption keys:"
    age-keygen \
        | awk \
              '
               $0 ~ /^# public key: .*$/ {
                   print "export KUBEDEMO_PUBLIC_KEY=" $4;
               }
               $1 ~ /^AGE-SECRET-KEY-.*$/ {
                   print "export KUBEDEMO_PRIVATE_KEY=" $1; }
              ' \
                  >> "$AGE_KEYS_FILE" \
                  || exit 1
fi

echo "  Sourcing AGE encryption keys from $AGE_KEYS_FILE:"
. "$AGE_KEYS_FILE" \
    || exit 1


echo "  Adding secrets store CSI driver Helm repo:"
helm repo add secrets-store-csi-driver \
     https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts \
     --kubeconfig $KUBECONFIG \
    || exit 1

echo "  Kicking Helm:"
helm repo update \
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

echo "  Kicking Helm:"
helm repo update \
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
IS_VAULT_RUNNING=false
for TRY_NUM in 1 2 3
do
    kubectl wait pod \
        --selector 'app.kubernetes.io/name=vault' \
	--for jsonpath='{.status.phase}'=Running \
        --timeout 120s \
	--namespace vault \
        --kubeconfig $KUBECONFIG
    if test $? -eq 0
    then
        IS_VAULT_RUNNING=true
        break
    fi

    echo "    Waiting 2 seconds for Vault pods..."
    sleep 2
done

if test "$IS_VAULT_RUNNING" != "true"
then
    echo "ERROR Vault Pods are still not running." >&2
    exit 1
fi

#
# Now initialize Vault:
#
#     https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-raft-deployment-guide#initialize-and-unseal-vault
#
# VAULT_KEYS should look something along the lines of:
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
    echo "  Initializing Vault:"
    VAULT_KEYS=`kubectl exec \
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

    # VAULT_UNSEAL_KEY_1=MBFSDepD9E6whREc6Dj+k3pMaKJ6cCnCUWcySJQymObb
    # VAULT_UNSEAL_KEY_2=zQj4v22k9ixegS+94HJwmIaWLBL3nZHe1i+b/wHz25fr
    # VAULT_UNSEAL_KEY_3=7dbPPeeGGW3SmeBFFo04peCKkXFuuyKc8b2DuntA4VU5
    # VAULT_UNSEAL_KEY_4=tLt+ME7Z7hYUATfWnuQdfCEgnKA2L173dptAwfmenCdf
    # VAULT_UNSEAL_KEY_5=vYt9bxLr0+OzJ8m7c7cNMFj7nvdLljj0xWRbpLezFAI9
    # VAULT_INITIAL_ROOT_TOKEN=s.zJNwZlRrqISjyBHFMiEca6GF
    echo "  Extracting Vault unseal keys and initial root token into env:"
    VAULT_ENV=`echo "$VAULT_KEYS" \
                   | awk '
                          $0 ~ /^[ ]*Unseal Key [1-9][0-9]*: .*$/ {
                              unseal_key_num = $3;
                              gsub(/:/, "", unseal_key_num);
                              print "VAULT_UNSEAL_KEY_" unseal_key_num "=" $4;
                          }
                          $0 ~ /^[ ]*Initial Root Token: .*$/ {
                              print "VAULT_INITIAL_ROOT_TOKEN=" $4;
                          }
                         '`
    if test $? -ne 0 \
            -o -z "$VAULT_ENV"
    then
        echo "ERROR Failed to turn Vault keys into environment variables" >&2
        exit 1
    fi

    echo "  Storing Vault unseal keys and initial root token in $HOME/vault_keys.decrypted.env:"
    touch $HOME/vault_keys.decrypted.env \
        || exit 1
    echo "$VAULT_ENV" \
         > $HOME/vault_keys.decrypted.env \
        || exit 1

    echo "  Encrypting $HOME/vault_keys.decrypted.env -> $HOME/vault_keys.encrypted.env:"
    sops --encrypt \
        --age "$KUBEDEMO_PUBLIC_KEY" \
        --output "$HOME/vault_keys.encrypted.env" \
        "$HOME/vault_keys.decrypted.env" \
        || exit 1
    chmod u-wx,go-rwx $HOME/vault_keys.encrypted.env \
        || exit 1
    rm -f "$HOME/vault_keys.decrypted.env" \
        || exit 1
else
    VAULT_ENV=`cat $HOME/vault_keys.encrypted.env`
    if test -z "$VAULT_ENV"
    then
        echo "ERROR Vault has already been initialized, but there is no $HOME/vault_keys.encrypted.env to unseal it." >&2
        exit 1
    fi
fi

$RUN_DIR/sops_run.sh \
    "$HOME/vault_keys.encrypted.env" \
    '
        IS_OK=true
        if test -z "$VAULT_UNSEAL_KEY_1" \
            -o -z "$VAULT_UNSEAL_KEY_2" \
            -o -z "$VAULT_UNSEAL_KEY_3" \
            -o -z "$VAULT_UNSEAL_KEY_4" \
            -o -z "$VAULT_UNSEAL_KEY_5"
        then
            IS_OK=false
            echo "ERROR VAULT_UNSEAL_KEY_... (1-5) variable(s) not set!" >&2
        fi
        if test -z "$VAULT_INITIAL_ROOT_TOKEN"
        then
            IS_OK=false
            echo "ERROR VAULT_INITIAL_ROOT_TOKEN variable is not set!" >&2
        fi
        if test "$IS_OK" == "true"
        then
            exit 0
        else
            exit 1
        fi
    ' \
        || exit 1

echo "SUCCESS Installing secrets (HashiCorp Vault)."
exit 0
