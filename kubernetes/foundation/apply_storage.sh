#!/bin/sh

#
# Rook/Ceph for storage.
#
# Version 1.13.3 from:
#
#     https://github.com/rook/rook/releases
#
# (Note that cluster/storage-rook-operator.yaml explicitly mentions
# the version number, to pull down the appropriate version of the
# Rook operator; but the other cluster/storage-rook-*.yaml manifests
# might need to change, too, as new versions of Rook are released.)
#
# This version of Rook/Ceph is supported on version 1.29 of Kubernetes:
#
#     https://rook.io/docs/rook/latest-release/Getting-Started/quickstart/#kubernetes-version
#
echo "Installing storage (Rook/Ceph)..."

CLUSTER_DIR=/cloud-init/kubernetes/foundation/cluster
KUBECONFIG=$HOME/.kube/kubeconfig-kubedemo.yaml

echo "  Installing Rook operator:"
kubectl apply \
        --filename $CLUSTER_DIR/storage-rook-crds.yaml \
        --filename $CLUSTER_DIR/storage-rook-common.yaml \
        --filename $CLUSTER_DIR/storage-rook-operator.yaml \
        --kubeconfig ~/.kube/kubeconfig-kubedemo.yaml \
    || exit 1

echo "  Creating Rook storage cluster:"
kubectl apply \
        --filename $CLUSTER_DIR/storage-rook-cluster.yaml \
        --kubeconfig ~/.kube/kubeconfig-kubedemo.yaml \
    || exit 1

echo "  Creating Rook CephBlockPool:"
kubectl apply \
        --filename $CLUSTER_DIR/storage-rook-blockpool.yaml \
        --filename $CLUSTER_DIR/storage-rook-storageclass.yaml \
        --kubeconfig ~/.kube/kubeconfig-kubedemo.yaml \
    || exit 1

echo "  Waiting for Rook/Ceph pods to be ready..."
# 10 minutes is a long time...!
MAX_SECONDS=600
SLEEP_SECONDS=30
TOTAL_SECONDS=0
while test $TOTAL_SECONDS -lt $MAX_SECONDS
do
    NUM_MONS_OSDS_READY=`kubectl get deployments \
                             --namespace rook-ceph \
                             --kubeconfig $KUBECONFIG \
                             | awk '
                                    $1 == "rook-ceph-mon-a" { print $0; }
                                    $1 == "rook-ceph-mon-b" { print $0; }
                                    $1 == "rook-ceph-mon-c" { print $0; }
                                    $1 == "rook-ceph-osd-0" { print $0; }
                                    $1 == "rook-ceph-osd-1" { print $0; }
                                    $1 == "rook-ceph-osd-2" { print $0; }
                                   ' \
                             | awk '$2 == "1/1" { print $0; }' \
                             | wc -l \
                             2>&1`
    if test $? -ne 0 \
            -o "$NUM_MONS_OSDS_READY" -lt 6
    then
        if test $TOTAL_SECONDS -eq 0
        then
            echo "    Not all 3 mons + 3 osds are up yet: $NUM_MONS_OSDS_READY"
        else
            echo "      ... $NUM_MONS_OSDS_READY ($TOTAL_SECONDS s / $MAX_SECONDS s)"
        fi
        sleep $SLEEP_SECONDS
        NEW_TOTAL_SECONDS=`expr $TOTAL_SECONDS + $SLEEP_SECONDS`
        TOTAL_SECONDS=$NEW_TOTAL_SECONDS
        continue
    fi

    kubectl get deployments \
        --namespace rook-ceph \
        --kubeconfig $KUBECONFIG \
        | awk '
               $1 == "rook-ceph-mon-a" { print $0; }
               $1 == "rook-ceph-mon-b" { print $0; }
               $1 == "rook-ceph-mon-c" { print $0; }
               $1 == "rook-ceph-osd-0" { print $0; }
               $1 == "rook-ceph-osd-1" { print $0; }
               $1 == "rook-ceph-osd-2" { print $0; }
              ' \
                  | sed 's|^\(.*\)$|      \1|'

    echo "    Rook/Ceph is ready now."
    break
done

if test $TOTAL_SECONDS -ge $MAX_SECONDS
then
    echo "ERROR Rook/Ceph still isn't ready after $TOTAL_SECONDS" >&2
    exit 1
fi


echo "SUCCESS Installing storage (Rook/Ceph)."
exit 0
