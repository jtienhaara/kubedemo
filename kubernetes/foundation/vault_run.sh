#!/bin/sh

if test $# -lt 1
then
    echo "Usage: $0 (vault-command) (arg)..." >&2
    exit 1
fi

VAULT_COMMAND=$@


CLUSTER_DIR=/cloud-init/kubernetes/foundation/cluster
KUBECONFIG=$HOME/.kube/kubeconfig-kubedemo.yaml
RUN_DIR=`dirname $0`

if test ! -x "$RUN_DIR/sops_run.sh"
then
    echo "ERROR sops_run.sh is required for $0, but is either missing or not executable: $RUN_DIR/sops_run.sh" >&2
    exit 1
fi

AGE_KEYS_FILE=$HOME/age-keys.env
VAULT_KEYS_FILE=$HOME/vault_keys.encrypted.env

if test ! -e "$AGE_KEYS_FILE"
then
    echo "ERROR No AGE public/private keys found to decrypt the Vault secrets - did apply_secrets.sh run?  $AGE_KEYS_FILE" >&2
    exit 1
elif test ! -e "$VAULT_KEYS_FILE"
then
    echo "ERROR No Vault unseal keys and root token file - did apply_secrets.sh run successfully?  $VAULT_KEYS_FILE" >&2
    exit 1
fi

. "$AGE_KEYS_FILE" \
    || exit 1

$RUN_DIR/sops_run.sh \
    "$VAULT_KEYS_FILE" \
    echo '$VAULT_INITIAL_ROOT_TOKEN' \
        | kubectl exec -i vault-0 \
              --namespace vault \
              --kubeconfig $KUBECONFIG \
              -- \
              sh -c "vault login \
                         -ca-cert /opt/vault/tls/vault-0/ca.crt \
                         -client-cert /opt/vault/tls/vault-0/tls.crt \
                         -client-key /opt/vault/tls/vault-0/tls.key \
                         -no-print \
                         - \
                         && $VAULT_COMMAND"
EXIT_CODE=$?
exit $EXIT_CODE
