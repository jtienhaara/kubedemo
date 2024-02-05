#!/bin/sh

#
# cert-manager for certificates.
#
# Version 1.14.1 from:
#
#     https://github.com/cert-manager/cert-manager/releases
#
# This version of cert-manager is supported on version 1.29 of Kubernetes:
#
#     https://cert-manager.io/docs/releases/#currently-supported-releases
#
echo "Installing certificates (cert-manager)..."

CLUSTER_DIR=/cloud-init/kubernetes/foundation/cluster
KUBECONFIG=$HOME/.kube/kubeconfig-kubedemo.yaml

echo "  Installing cert-manager CRDs and resources all at once:"
kubectl apply \
        --filename $CLUSTER_DIR/certificates-cert-manager-resources.yaml \
        --kubeconfig ~/.kube/kubeconfig-kubedemo.yaml \
    || exit 1

CERT_MANAGER_DEPLOYMENTS="cert-manager-cainjector cert-manager cert-manager-webhook"

echo "  Waiting for cert-manager Deployments ($CERT_MANAGER_DEPLOYMENTS) to be ready..."
# 2 minutes should be plenty for cert-manager.
MAX_SECONDS=120
SLEEP_SECONDS=15
TOTAL_SECONDS=0
while test $TOTAL_SECONDS -lt $MAX_SECONDS
do
    NUM_DEPLOYMENTS_READY=`kubectl get deployments \
                               --namespace cert-manager \
                               --kubeconfig $KUBECONFIG \
                               | awk '$2 == "1/1" { print $0; }' \
                               | wc -l \
                               2>&1`
    if test $? -ne 0 \
            -o "$NUM_DEPLOYMENTS_READY" != "3"
    then
        if test $TOTAL_SECONDS -eq 0
        then
            echo "    Not all 3 cert-manager Deployments are up yet: $NUM_DEPLOYMENTS_READY"
        else
            echo "      ... $NUM_DEPLOYMENTS_READY ($TOTAL_SECONDS s / $MAX_SECONDS s)"
        fi
        sleep $SLEEP_SECONDS
        NEW_TOTAL_SECONDS=`expr $TOTAL_SECONDS + $SLEEP_SECONDS`
        TOTAL_SECONDS=$NEW_TOTAL_SECONDS
        continue
    fi

    kubectl get deployments \
        --namespace cert-manager \
        --kubeconfig $KUBECONFIG \
        | sed 's|^\(.*\)$|      \1|'

    echo "    cert-manager is ready now."
    break
done

if test $TOTAL_SECONDS -ge $MAX_SECONDS
then
    echo "ERROR cert-manager still isn't ready after $TOTAL_SECONDS" >&2
    exit 1
fi

echo "SUCCESS Installing certificates (cert-manager)."
exit 0
