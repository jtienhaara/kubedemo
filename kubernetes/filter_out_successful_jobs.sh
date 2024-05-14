#!/bin/sh

RUN_DIR=`dirname $0`

KUBECONFIG=$HOME/.kube/kubeconfig-kubedemo.yaml

while read POD_LINE_FROM_ALL_NAMESPACES
do
    NAMESPACE=`echo "$POD_LINE_FROM_ALL_NAMESPACES" \
                   | awk '{ print $1; }'`
    POD_NAME=`echo "$POD_LINE_FROM_ALL_NAMESPACES" \
                  | awk '{ print $2; }'`

    JOB_NAME=`$RUN_DIR/job_from_pod.sh "$NAMESPACE" "$POD_NAME" \
                  2> /dev/null`
    if test $? -ne 0 \
            -o -z "$JOB_NAME"
    then
        echo "$POD_LINE_FROM_ALL_NAMESPACES"
        continue
    fi

    NUM_SUCCESSES=`kubectl get job "$JOB_NAME" \
                       --namespace "$NAMESPACE" \
                       --output jsonpath \
                       --template '{.status.succeeded}' \
                       --kubeconfig $KUBECONFIG`
    if test $? -ne 0 \
            -o -z "$NUM_SUCCESSES"
    then
        echo "$POD_LINE_FROM_ALL_NAMESPACES"
        continue
    fi

    if test $NUM_SUCCESSES -ne 1
    then
        echo "$POD_LINE_FROM_ALL_NAMESPACES"
        continue
    fi

    #
    # This Pod seems to be a failed early run from a Job that
    # eventually succeeded.
    #
done

exit 0
