#!/bin/sh

FOUNDATION_DIR=`dirname $0`
ROOT_DIR=`dirname $FOUNDATION_DIR`
KUBECONFIG=$HOME/.kube/kubeconfig-kubedemo.yaml
KUSTOMIZED_FILE=$HOME/kustomized-foundation.yaml

echo "      Applying foundation layer Kubernetes components..."

kustomize build $FOUNDATION_DIR/ \
          > $KUSTOMIZED_FILE
if test $? -ne 0
then
    echo "ERROR Could not kustomize build $FOUNDATION_DIR/" >&2
    exit 1
fi

echo "        Running kubectl apply:"
# 30 minutes is a long time...!
IS_APPLIED=false
MAX_SECONDS=1800
SLEEP_SECONDS=10
TOTAL_SECONDS=0
while test $TOTAL_SECONDS -lt $MAX_SECONDS
do
    kubectl apply --filename $KUSTOMIZED_FILE --kubeconfig $KUBECONFIG
    if test $? -ne 0
    then
        echo "          Trying kubectl apply again in $SLEEP_SECONDS seconds..."
        sleep $SLEEP_SECONDS
        continue
    fi

    IS_APPLIED=true
    break
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

    NEXT_UNREADY_PODS=`echo "$GET_UNRUNNING_PODS" \
                           | tail '+2'`
    if test -z "$NEXT_UNREADY_PODS"
    then
        echo "        All Pods are now running."
        break
    fi

    if test "$NEXT_UNREADY_PODS" != "$LAST_UNREADY_PODS"
    then
        echo "        Not yet running pods:"
        echo "$NEXT_UNREADY_PODS" \
            | sed 's|^\(.*\)$|          \1|'
        LAST_UNREADY_PODS=$NEXT_UNREADY_PODS
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
