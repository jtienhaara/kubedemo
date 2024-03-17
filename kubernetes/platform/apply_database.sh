#!/bin/sh

#
# kubegres for high availability PostgreSQL database cluster.
#
# Version 1.17 from:
#
#     https://github.com/reactive-tech/kubegres/tree/v1.17
#
# Licensed under the Apache 2.0 license:
#
#     https://github.com/reactive-tech/kubegres/blob/v1.17/LICENCE
#

KUBEGRES_VERSION=1.17

echo "Installing database (kubegres $KUBEGRES_VERSION)..."

CLUSTER_DIR=/cloud-init/kubernetes/platform/cluster
KUBECONFIG=$HOME/.kube/kubeconfig-kubedemo.yaml
RUN_DIR=`dirname $0`
VAULT_RUN="$RUN_DIR/../foundation/vault_run.sh"

if test ! -x "$VAULT_RUN"
then
    echo "ERROR vault_run.sh is required for $0, but is either missing or not executable: $VAULT_RUN" >&2
    exit 1
fi

echo "  Installing kubegres CRDs and operator:"
kubectl apply \
        --filename $CLUSTER_DIR/database-kubegres-operator.yaml \
        --kubeconfig $KUBECONFIG \
    || exit 1

echo "  Waiting for kubegres database to finish installing CRDs:"
kubectl wait \
	--for condition=Established \
	--all CustomResourceDefinition \
	--namespace kubegres-system \
        --kubeconfig $KUBECONFIG \
    || exit 1

KUBEGRES_DEPLOYMENTS="kubegres-controller-manager"

echo "  Waiting for kubegres Deployments ($KUBEGRES_DEPLOYMENTS) to be ready..."
# 1 minute should be plenty for kubegres.
MAX_SECONDS=60
SLEEP_SECONDS=10
TOTAL_SECONDS=0
while test $TOTAL_SECONDS -lt $MAX_SECONDS
do
    NUM_DEPLOYMENTS_READY=`kubectl get deployments \
                               --namespace kubegres-system \
                               --kubeconfig $KUBECONFIG \
                               | awk '$2 == "1/1" { print $0; }' \
                               | wc -l \
                               2>&1`
    if test $? -ne 0 \
            -o $NUM_DEPLOYMENTS_READY -lt 1
    then
        if test $TOTAL_SECONDS -eq 0
        then
            echo "    Not all 1 kubegres Deployments are up yet: $NUM_DEPLOYMENTS_READY"
        else
            echo "      ... $NUM_DEPLOYMENTS_READY ($TOTAL_SECONDS s / $MAX_SECONDS s)"
        fi
        sleep $SLEEP_SECONDS
        NEW_TOTAL_SECONDS=`expr $TOTAL_SECONDS + $SLEEP_SECONDS`
        TOTAL_SECONDS=$NEW_TOTAL_SECONDS
        continue
    fi

    kubectl get deployments \
        --namespace kubegres-system \
        --kubeconfig $KUBECONFIG \
        | sed 's|^\(.*\)$|      \1|'

    echo "    kubegres is ready now."
    break
done

if test $TOTAL_SECONDS -ge $MAX_SECONDS
then
    echo "ERROR kubegres still isn't ready after $TOTAL_SECONDS" >&2
    exit 1
fi


echo "  Creating 'db' Namespace:"
kubectl apply \
        --filename $CLUSTER_DIR/database-db-namespace.yaml \
        --kubeconfig $KUBECONFIG \
    || exit 1

echo "  Creating 'dbadmin' ServiceAccount:"
kubectl apply \
        --filename $CLUSTER_DIR/database-dbadmin-service-account.yaml \
        --kubeconfig $KUBECONFIG \
    || exit 1

VAULT_DATABASE_PASSWORDS_POLICY='
path "secret/data/postgres-passwords" {
  capabilities = ["read"]
}
'

echo "  Creating database policy for PostgreSQL to mount password secrets:"
$VAULT_RUN \
    "echo '$VAULT_DATABASE_PASSWORDS_POLICY' \
         | vault policy write \
            -ca-cert /opt/vault/tls/vault-0/ca.crt \
            -client-cert /opt/vault/tls/vault-0/tls.crt \
            -client-key /opt/vault/tls/vault-0/tls.key \
            -non-interactive \
            postgres-passwords -" \
    || exit 1

echo "  Creating Vault database-admin role to mount password secrets:"
$VAULT_RUN \
    "vault write \
         -ca-cert /opt/vault/tls/vault-0/ca.crt \
         -client-cert /opt/vault/tls/vault-0/tls.crt \
         -client-key /opt/vault/tls/vault-0/tls.key \
         -non-interactive \
         auth/kubernetes/role/database-admin \
         bound_service_account_names=dbadmin \
         bound_service_account_namespaces=database \
         policies=postgres-passwords" \
    || exit 1

#
# From:
#
#     https://developer.hashicorp.com/vault/docs/secrets/kv/kv-v2#writing-reading-arbitrary-data
#
# (Cf. "You can also use Vault's password policy feature to generate arbitrary values.")
#
echo "  Creating PostgreSQL root and replication password secrets in Vault:"
$VAULT_RUN \
    'vault kv put \
         -ca-cert /opt/vault/tls/vault-0/ca.crt \
         -client-cert /opt/vault/tls/vault-0/tls.crt \
         -client-key /opt/vault/tls/vault-0/tls.key \
         -non-interactive \
         secret/data/postgres-passwords \
         superUserPassword=`vault read \
             -ca-cert /opt/vault/tls/vault-0/ca.crt \
             -client-cert /opt/vault/tls/vault-0/tls.crt \
             -client-key /opt/vault/tls/vault-0/tls.key \
             -non-interactive \
             -field password \
             sys/policies/password/kubedemo-password/generate` \
         replicationUserPassword=`vault read \
             -ca-cert /opt/vault/tls/vault-0/ca.crt \
             -client-cert /opt/vault/tls/vault-0/tls.crt \
             -client-key /opt/vault/tls/vault-0/tls.key \
             -non-interactive \
             -field password \
             sys/policies/password/kubedemo-password/generate`' \
    || exit 1

#
# You can now run something along the lines of the following to see
# the Postgres superUserPassword and replicationUserPassword from Vault:
#
#     kubectl exec -i --tty vault-0 --namespace vault --kubeconfig $HOME/.kube/kubeconfig-kubedemo.yaml -- sh -c 'vault kv get -ca-cert /opt/vault/tls/vault-0/ca.crt -client-cert /opt/vault/tls/vault-0/tls.crt -client-key /opt/vault/tls/vault-0/tls.key -non-interactive secret/data/postgres-passwords'
#
# With something like the following output:
#
#     =========== Secret Path ===========
#     secret/data/data/postgres-passwords
#
#     ======= Metadata =======
#     Key                Value
#     ---                -----
#     created_time       2024-03-14T23:10:48.513124693Z
#     custom_metadata    <nil>
#     deletion_time      n/a
#     destroyed          false
#     version            1
#
#     ============= Data =============
#     Key                        Value
#     ---                        -----
#     replicationUserPassword    b4P1M|vOQ!DUQqPYi^V6^lw(5xPJp.~Y
#     superUserPassword          zh]umJ9aFMy]9>:K0JSo*]rl|cQ3PJ#S
#

echo "SUCCESS Installing database (kubegres $KUBEGRES_VERSION)."
exit 0
