#!/bin/sh

VAULT_HELM_VERSION=0.25.0
VAULT_VERSION=1.14.0
VAULT_CSI_VERSION=1.4.1

CSI_DRIVER_HELM_VERSION=1.4.1

CLUSTER_DIR=/cloud-init/kubernetes/foundation/cluster
KUBECONFIG=$HOME/.kube/kubeconfig-kubedemo.yaml
RUN_DIR=`dirname $0`

if test ! -x "$RUN_DIR/sops_run.sh"
then
    echo "ERROR sops_run.sh is required for $0, but is either missing or not executable: $RUN_DIR/sops_run.sh" >&2
    exit 1
fi

echo "Unsealing vault Pods..."

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

echo "  Sourcing AGE encryption keys from $AGE_KEYS_FILE:"
. "$AGE_KEYS_FILE" \
    || exit 1

VAULT_PODS="vault-0 vault-1 vault-2"
IS_ALL_READY=true
MAX_TRIES=3
for TRY_NUM in 1 2 3
do
    if test $TRY_NUM -gt 1
    then
        echo "    Trying again (try # $TRY_NUM)..."
    fi

    IS_ALL_READY=true

    for VAULT_POD in $VAULT_PODS
    do
        IS_VAULT_POD_READY=false
        for UNSEAL_KEY_NUM in 1 2 3 4 5
        do
            #
            # Race condition:
            # Sometimes one of the Pods will restart and not know it's initialized
            # at the same we try to unseal it.  Waiting a bit then trying
            # again should allow it to connect with the other Pods and realize
            # it is initialized.
            #
            #       Initializing Vault:
            #       Storing Vault unseal keys and initial root token in /home/kubedemo/.vault_keys:
            #       Unsealing vault Pods...
            #         Unsealing vault-0 with unseal key 1:
            #     ...
            #           vault-0 is now ready.
            #         Unsealing vault-1 with unseal key 1:
            #     Error unsealing: Error making API request.
            #     URL: PUT https://127.0.0.1:8200/v1/sys/unseal
            #     Code: 400. Errors:
            #     * Vault is not initialized
            #     command terminated with exit code 2
            #
            echo "    Unsealing $VAULT_POD with unseal key $UNSEAL_KEY_NUM:"
            $RUN_DIR/sops_run.sh \
                "$VAULT_KEYS_FILE" \
                kubectl exec \
                    "$VAULT_POD" --namespace vault --kubeconfig $KUBECONFIG -- \
                    vault operator unseal \
                        -ca-cert /opt/vault/tls/$VAULT_POD/ca.crt \
                        -non-interactive \
                        "\$VAULT_UNSEAL_KEY_$UNSEAL_KEY_NUM"

            if test $UNSEAL_KEY_NUM -ge 3
            then
                echo "      Waiting up to 2 seconds after unseal key # $UNSEAL_KEY_NUM to see if $VAULT_POD is ready:"
                kubectl wait pod/$VAULT_POD \
	            --for condition=Ready \
                        --timeout 2s \
	            --namespace vault \
                        --kubeconfig $KUBECONFIG \
                        2> /dev/null
                if test $? -eq 0
                then
                    echo "      $VAULT_POD is now ready."
                    IS_VAULT_POD_READY=true
                    break
                fi
            fi
        done

        if test "$IS_VAULT_POD_READY" != "true"
        then
            echo "      Waiting up to 2 seconds to see if $VAULT_POD is ready:"
            kubectl wait pod/$VAULT_POD \
	        --for condition=Ready \
                    --timeout 2s \
	        --namespace vault \
                    --kubeconfig $KUBECONFIG \
                    2> /dev/null
            if test $? -eq 0
            then
                echo "      $VAULT_POD is now ready."
                IS_VAULT_POD_READY=true
            else
                IS_ALL_READY=false
            fi
        fi
    done

    if test "$IS_ALL_READY" = "true"
    then
        break
    fi

    #
    # Else try again.
    #
done

if test "$IS_ALL_READY" != "true"
then
    echo "ERROR Failed to unseal all Vault pods ($VAULT_PODS) after $MAX_TRIES tries." >&2
    exit 1
fi

echo "SUCCESS Unsealing vault Pods."
exit 0
