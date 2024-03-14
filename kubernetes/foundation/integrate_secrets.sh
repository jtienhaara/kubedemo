#!/bin/sh

#
# Integrate Vault:
#
# - Turn on Prometheus metrics (/v1/sys/metrics)
#

echo "Integrating Vault secrets with apps..."

CLUSTER_DIR=/cloud-init/kubernetes/foundation/cluster
KUBECONFIG=$HOME/.kube/kubeconfig-kubedemo.yaml
RUN_DIR=`dirname $0`

if test ! -x "$RUN_DIR/vault_run.sh"
then
    echo "ERROR vault_run.sh is required for $0, but is either missing or not executable: $RUN_DIR/vault_run.sh" >&2
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

#
# Enable Kubernetes authentication, so we can mount Vault secrets
# using CSI.
#
echo "  Enabling Vault Kubernetes authentication:"
$RUN_DIR/vault_run.sh \
    "vault auth enable \
         -ca-cert /opt/vault/tls/vault-0/ca.crt \
         -client-cert /opt/vault/tls/vault-0/tls.crt \
         -client-key /opt/vault/tls/vault-0/tls.key \
         -non-interactive \
         kubernetes" \
    || exit 1

echo "    Configuring Vault Kubernetes authentication:"
$RUN_DIR/vault_run.sh \
    'vault write \
         -ca-cert /opt/vault/tls/vault-0/ca.crt \
         -client-cert /opt/vault/tls/vault-0/tls.crt \
         -client-key /opt/vault/tls/vault-0/tls.key \
         -non-interactive \
         auth/kubernetes/config \
         kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443"' \
    || exit 1

#
# Needed to enable metrics.  From:
#
#     https://developer.hashicorp.com/vault/tutorials/monitoring/monitor-telemetry-grafana-prometheus#define-prometheus-acl-policy
#
VAULT_METRICS_POLICY='
path "/sys/metrics" {
  capabilities = ["read"]
}
'

echo "  Enabling Vault metrics /v1/sys/metrics:"
$RUN_DIR/vault_run.sh \
    "echo '$VAULT_METRICS_POLICY' \
         | vault policy write \
               -ca-cert /opt/vault/tls/vault-0/ca.crt \
               -client-cert /opt/vault/tls/vault-0/tls.crt \
               -client-key /opt/vault/tls/vault-0/tls.key \
               -non-interactive \
               prometheus-metrics -" \
    || exit 1

$RUN_DIR/vault_run.sh \
    "vault write \
         -ca-cert /opt/vault/tls/vault-0/ca.crt \
         -client-cert /opt/vault/tls/vault-0/tls.crt \
         -client-key /opt/vault/tls/vault-0/tls.key \
         -non-interactive \
         auth/kubernetes/role/metrics \
         bound_service_account_names=prometheus-k8s \
         bound_service_account_namespaces=monitoring \
         policies=prometheus-metrics" \
    || exit 1

#
# Enable some secrets engines:
#
#     - key/value (version 2)
#
echo "  Enabling Vault kv (version 2) secrets:"
$RUN_DIR/vault_run.sh \
    "vault secrets enable \
         -ca-cert /opt/vault/tls/vault-0/ca.crt \
         -client-cert /opt/vault/tls/vault-0/tls.crt \
         -client-key /opt/vault/tls/vault-0/tls.key \
         -non-interactive \
         kv-v2" \
    || exit 1

echo "SUCCESS Integrating Vault secrets with apps."
exit 0
