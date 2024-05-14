#!/bin/sh

if test $# -lt 2
then
    echo "Usage: $0 (namespace) (pod-name) (ignored)..." >&2
    echo "" >&2
    exit 1
fi

NAMESPACE=$1
POD_NAME=$2
KUBECONFIG=$HOME/.kube/kubeconfig-kubedemo.yaml

kubectl get pod "$POD_NAME" \
        --namespace "$NAMESPACE" \
        --kubeconfig $KUBECONFIG \
        --output jsonpath \
        --template '{.metadata.ownerReferences[?(@.kind == "Job")].name}' \
    || exit 1

exit 0
