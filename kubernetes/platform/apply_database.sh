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

echo "SUCCESS Installing database (kubegres $KUBEGRES_VERSION)."
exit 0
