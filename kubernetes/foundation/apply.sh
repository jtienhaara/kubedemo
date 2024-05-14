#!/bin/sh

FOUNDATION_DIR=`dirname $0`
ROOT_DIR=`dirname $FOUNDATION_DIR`
KUBECONFIG=$HOME/.kube/kubeconfig-kubedemo.yaml
KUSTOMIZED_FILE=$HOME/kustomized-foundation.yaml
KUSTOMIZED_DIR=$HOME/kustomized-foundation

echo "      Applying foundation layer Kubernetes components..."

echo "        Building kustomized file $KUSTOMIZED_FILE:"
kustomize build --enable-helm=true $FOUNDATION_DIR/ \
          > $KUSTOMIZED_FILE
if test $? -ne 0
then
    echo "ERROR Could not kustomize build $FOUNDATION_DIR/" >&2
    exit 1
fi

#
# If we don't split the huge (5.6 MB) kustomized YAML file into pieces
# we'll get weird errors, such as:
#
#     conflict with" "rook" "using ceph.rook.io/v1: .spec.storage.storageClassDeviceSets
#
# No idea why.  Splitting the massive YAML file up seems to fix this...
#
echo "        Splitting kustomized file into individual manifests:"
kubectl-slice \
    --template '{{.metadata.namespace}}-{{.kind | lower}}-{{.metadata.name}}.yaml' \
    --input-file $KUSTOMIZED_FILE \
    --output-dir $KUSTOMIZED_DIR/ \
    || exit 1

echo "        Running kubectl apply:"
# 30 minutes is a long time...!
IS_APPLIED=false
MAX_SECONDS=1800
SLEEP_SECONDS=10
TOTAL_SECONDS=0
while test $TOTAL_SECONDS -lt $MAX_SECONDS
do
    IS_APPLIED=true

    #
    # Apply then delete each manifest.  Whatever's left, after
    # trying to kubectl apply everything over and over for a long time,
    # is what failed.
    #
    for MANIFEST in $KUSTOMIZED_DIR/*.yaml
    do
        #
        # kubectl apply --server-side=true is required to avoid errors:
        #
        #     Too long: must have at most 262144 bytes
        #
        kubectl apply \
                --filename "$MANIFEST" \
                --server-side=true \
                --kubeconfig $KUBECONFIG
        if test $? -eq 0
        then
            rm "$MANIFEST" \
                || exit 1
        else
            IS_APPLIED=false
        fi
    done

    if test "$IS_APPLIED" = "true"
    then
        break
    fi

    NEW_TOTAL_SECONDS=`expr $TOTAL_SECONDS + $SLEEP_SECONDS`
    TOTAL_SECONDS=$NEW_TOTAL_SECONDS
    if test $TOTAL_SECONDS -ge $MAX_SECONDS
    then
        break
    fi

    echo "          Trying kubectl apply again in $SLEEP_SECONDS seconds..."
    sleep $SLEEP_SECONDS
done

if test $TOTAL_SECONDS -ge $MAX_SECONDS
then
    echo "ERROR Foundation kubectl apply still failing after $TOTAL_SECONDS" >&2
    exit 1
fi

echo "        kubectl apply succeeded."


echo "        Waiting for all Pods to be Running:"
# 30 minutes is a long time...!
LAST_UNREADY_PODS="(not yet run)"
MAX_SECONDS=1800
SLEEP_SECONDS=10
TOTAL_SECONDS=0
while test ! -z "$LAST_UNREADY_PODS" \
           -a $TOTAL_SECONDS -lt $MAX_SECONDS
do
    #
    # Get the not-running pods, but remove the header line.
    #
    GET_UNRUNNING_PODS=`$ROOT_DIR/get_unrunning_pods.sh`
    if test $? -ne 0
    then
        echo "ERROR Failed to retrieve the not-running pods with $ROOT_DIR/get_unrunning_pods.sh" >&2
        exit 1
    fi

    #
    # Use tail to remove the header line;
    # and use sed to remove the amount of time since the Pod was launched.
    #
    NEXT_UNREADY_PODS=`echo "$GET_UNRUNNING_PODS" \
                           | tail '+2' \
                           | sed 's|\(.*\)[ ][ ]*[^ ][^ ]*$|\1|'`
    if test -z "$NEXT_UNREADY_PODS"
    then
        echo "        All Pods are now running."
        break
    fi

    if test "$NEXT_UNREADY_PODS" != "$LAST_UNREADY_PODS"
    then
        echo "        Not yet running pods:"
        #
        # Output useful information, including title row and time since launch:
        #
        echo "$GET_UNRUNNING_PODS" \
            | sed 's|^\(.*\)$|          \1|'
        LAST_UNREADY_PODS=$NEXT_UNREADY_PODS
    fi

    NEW_TOTAL_SECONDS=`expr $TOTAL_SECONDS + $SLEEP_SECONDS`
    TOTAL_SECONDS=$NEW_TOTAL_SECONDS
    if test $TOTAL_SECONDS -ge $MAX_SECONDS
    then
        break
    fi

    sleep $SLEEP_SECONDS
done

if test $TOTAL_SECONDS -ge $MAX_SECONDS
then
    echo "ERROR Foundation layer still isn't ready after $TOTAL_SECONDS" >&2
    exit 1
fi

echo "      SUCCESS Applying foundation layer Kubernetes components."
exit 0
