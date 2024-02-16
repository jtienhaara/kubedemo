#!/bin/sh

#
# Integrate Vault:
#
# - Turn on Prometheus metrics (/v1/sys/metrics)
#

echo "Integrating Vault secrets with apps..."

CLUSTER_DIR=/cloud-init/kubernetes/foundation/cluster
KUBECONFIG=$HOME/.kube/kubeconfig-kubedemo.yaml

echo "  Retrieving login info for Vault:"
VAULT_KEYS=`cat $HOME/.vault_keys`
if test -z "$VAULT_KEYS"
then
    echo "ERROR Vault keys do not exist - has apply_secrets.sh been run?  $HOME/.vault_keys" >&2
    exit 1
fi

#
# Need to login to Vault:
#
VAULT_ROOT_TOKEN=`echo "$VAULT_KEYS" \
                      | grep 'Initial Root Token: ' \
                      | sed 's|^Initial Root Token:[ ]*||'`
if test -z "$VAULT_ROOT_TOKEN"
then
    echo "ERROR Could not determine Initial Root Token from $HOME/.vault_keys" >&2
    exit 1
fi

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
echo "$VAULT_ROOT_TOKEN" \
    | kubectl exec -i vault-0 \
              --namespace vault \
              --kubeconfig $KUBECONFIG \
              -- \
              sh -c 'vault login \
                         -ca-cert /opt/vault/tls/vault-0/ca.crt \
                         -client-cert /opt/vault/tls/vault-0/tls.crt \
                         -client-key /opt/vault/tls/vault-0/tls.key \
                         -no-print \
                         - \
                         && echo "$VAULT_METRICS_POLICY" \
                                | vault policy write \
                                      -ca-cert /opt/vault/tls/vault-0/ca.crt \
                                      -client-cert /opt/vault/tls/vault-0/tls.crt \
                                      -client-key /opt/vault/tls/vault-0/tls.key \
                                      -non-interactive \
                                      prometheus-metrics -' \
    || exit 1

echo "SUCCESS Integrating Vault secrets with apps."
exit 0
