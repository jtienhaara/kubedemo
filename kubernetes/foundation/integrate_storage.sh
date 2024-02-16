#!/bin/sh

#
# Based on:
#
#     https://rook.io/docs/rook/v1.13/Storage-Configuration/Object-Storage-RGW/object-storage/#client-connections
#

#
# !!! TODO use vault for the secret (adjust rook s3 storage settings)
#

echo "Integrating storate with apps..."

CLUSTER_DIR=/cloud-init/kubernetes/foundation/cluster
KUBECONFIG=$HOME/.kube/kubeconfig-kubedemo.yaml

LOKI_BUCKET_HOST=`kubectl get configmap loki-bucket \
                      --namespace logs \
                      --output jsonpath='{.data.BUCKET_HOST}' \
                      --kubeconfig $KUBECONFIG`
LOKI_BUCKET_PORT=`kubectl get configmap loki-bucket \
                      --namespace logs \
                      --output jsonpath='{.data.BUCKET_PORT}' \
                      --kubeconfig $KUBECONFIG`
LOKI_BUCKET_NAME=`kubectl get configmap loki-bucket \
                      --namespace logs \
                      --output jsonpath='{.data.BUCKET_NAME}' \
                      --kubeconfig $KUBECONFIG`
LOKI_AWS_ACCESS_KEY_ID=`kubectl get secret loki-bucket \
                            --namespace logs \
                            --output jsonpath='{.data.AWS_ACCESS_KEY_ID}' \
                            --kubeconfig $KUBECONFIG`
LOKI_AWS_SECRET_ACCESS_KEY=`kubectl get secret loki-bucket \
                                --namespace logs \
                                --output jsonpath='{.data.AWS_SECRET_ACCESS_KEY}' \
                                --kubeconfig $KUBECONFIG`
if test -z "$LOKI_BUCKET_HOST" \
        -o -z "$LOKI_BUCKET_PORT" \
        -o -z "$LOKI_BUCKET_NAME" \
        -o -z "$LOKI_AWS_ACCESS_KEY_ID" \
        -o -z "$LOKI_AWS_SECRET_ACCESS_KEY"
then
    echo "ERROR Could not determine BUCKET_HOST ($LOKI_BUCKET_HOST) and/or BUCKET_PORT ($LOKI_BUCKET_PORT) and/or BUCKET_NAME ($LOKI_BUCKET_NAME) and/or AWS_ACCESS_KEY_ID ($LOKI_AWS_ACCESS_KEY_ID) and/or AWS_SECRET_ACCESS_KEY ($LOKI_AWS_SECRET_ACCESS_KEY) for Loki" >&2
    exit 1
fi

echo "SUCCESS Integrating storate with apps."
exit 0
