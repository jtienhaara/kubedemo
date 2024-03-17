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

echo "Creating database (kubegres $KUBEGRES_VERSION PostgreSQL cluster)..."

CLUSTER_DIR=/cloud-init/kubernetes/platform/cluster
KUBECONFIG=$HOME/.kube/kubeconfig-kubedemo.yaml

echo "  Creating db.postgres database cluster:"
kubectl apply \
        --filename $CLUSTER_DIR/database-kubegres-cluster.yaml \
        --kubeconfig $KUBECONFIG \
    || exit 1

POSTGRES_STATEFULSETS="postgres-1-0 postgres-2-0 postgres-3-0"

echo "  Waiting for postgres StatefulSets ($POSTGRES_STATEFULSETS) to be ready..."
# 5 minutes should be plenty for the postgresql pods.
MAX_SECONDS=300
SLEEP_SECONDS=30
TOTAL_SECONDS=0
while test $TOTAL_SECONDS -lt $MAX_SECONDS
do
    NUM_STATEFULSETS_READY=`kubectl get statefulsets \
                                --namespace db \
                                --kubeconfig $KUBECONFIG \
                                | awk '$2 == "1/1" { print $0; }' \
                                | wc -l \
                                2>&1`
    if test $? -ne 0 \
            -o $NUM_STATEFULSETS_READY -lt 3
    then
        if test $TOTAL_SECONDS -eq 0
        then
            echo "    Not all 3 postgres StatefulSets are up yet: $NUM_STATEFULSETS_READY"
        else
            echo "      ... $NUM_STATEFULSETS_READY ($TOTAL_SECONDS s / $MAX_SECONDS s)"
        fi
        sleep $SLEEP_SECONDS
        NEW_TOTAL_SECONDS=`expr $TOTAL_SECONDS + $SLEEP_SECONDS`
        TOTAL_SECONDS=$NEW_TOTAL_SECONDS
        continue
    fi

    kubectl get statefulsets \
        --namespace db \
        --kubeconfig $KUBECONFIG \
        | sed 's|^\(.*\)$|      \1|'

    echo "    postgres is ready now."
    break
done

if test $TOTAL_SECONDS -ge $MAX_SECONDS
then
    echo "ERROR postgres still isn't ready after $TOTAL_SECONDS" >&2
    exit 1
fi

echo "SUCCESS Creating database (kubegres $KUBEGRES_VERSION PostgreSQL cluster)."
exit 0
