#!/bin/sh

#
# cert-manager for certificates.
#
# Version 1.14.1 from:
#
#     https://github.com/cert-manager/cert-manager/releases
#
# cert-manager itself is licensed under the Apache 2.0 license,
# but the LICENSES file lists all kinds of dependency licneses that
# I'm afraid I have not gone through with a fine-toothed comb:
#
#     https://github.com/cert-manager/cert-manager/blob/v1.14.1/LICENSE
#     https://github.com/cert-manager/cert-manager/blob/v1.14.1/LICENSES
#
# This version of cert-manager is supported on version 1.29 of Kubernetes:
#
#     https://cert-manager.io/docs/releases/#currently-supported-releases
#
# trust-manager: https://cert-manager.io/docs/trust/trust-manager/
#
# Version 0.8.0 of trust-manager Helm Chart from:
#
#     https://github.com/cert-manager/trust-manager/releases
#
# trust-manager is licensed under the Apache 2.0 license:
#
#     https://github.com/cert-manager/trust-manager/blob/v0.8.0/LICENSE
#

CERT_MANAGER_VERSION=1.14.1
TRUST_MANAGER_HELM_CHART_VERSION=0.8.0

echo "Installing certificates (cert-manager $CERT_MANAGER_VERSION)..."

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
            -o $NUM_DEPLOYMENTS_READY -lt 3
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

#
# trust-manager: https://cert-manager.io/docs/trust/trust-manager/
#
echo "  Adding certificates jetstack Helm repo:"
helm repo add jetstack https://charts.jetstack.io --force-update \
    || exit 1

echo "  Kicking Helm:"
helm repo update \
     --kubeconfig $KUBECONFIG \
    || exit 1

echo "  Installing trust-manager Helm chart version $TRUST_MANAGER_HELM_CHART_VERSION:"
helm upgrade --install trust-manager jetstack/trust-manager \
     --version $TRUST_MANAGER_HELM_CHART_VERSION \
     --namespace cert-manager \
     --wait \
     --kubeconfig $KUBECONFIG \
    || exit 1

echo "  Creating root CA:"
kubectl apply \
        --filename $CLUSTER_DIR/certificates-cert-manager-root-ca.yaml \
        --kubeconfig $KUBECONFIG \
    || exit 1

echo "SUCCESS Installing certificates (cert-manager $CERT_MANAGER_VERSION)."
exit 0
