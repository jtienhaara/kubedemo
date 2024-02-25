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
ROOK_CEPH_VERSION=1.13.3

echo "Installing storage (Rook/Ceph)..."

CLUSTER_DIR=/cloud-init/kubernetes/foundation/cluster
KUBECONFIG=$HOME/.kube/kubeconfig-kubedemo.yaml

echo "  Installing Rook operator:"
kubectl apply \
        --filename $CLUSTER_DIR/storage-rook-crds.yaml \
        --filename $CLUSTER_DIR/storage-rook-common.yaml \
        --filename $CLUSTER_DIR/storage-rook-operator.yaml \
        --kubeconfig $KUBECONFIG \
    || exit 1

echo "  Creating Rook storage cluster:"
kubectl apply \
        --filename $CLUSTER_DIR/storage-rook-cluster.yaml \
        --kubeconfig $KUBECONFIG \
    || exit 1

echo "  Creating Rook CephBlockPool:"
kubectl apply \
        --filename $CLUSTER_DIR/storage-rook-blockpool.yaml \
        --filename $CLUSTER_DIR/storage-rook-storageclass.yaml \
        --kubeconfig $KUBECONFIG \
    || exit 1

echo "  Waiting for Rook/Ceph pods to be ready..."
# 20 minutes is a long time...!
MAX_SECONDS=1200
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

#
# Set up S3 object storage.
#
# TODO For now we don't use Vault for encryption at rest.
#
# xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
# We cannot set up Rook/Ceph S3 object storage until after HashiCorp
# Vault has been installed, since we depend on Vault to encrypt the
# S3 object storage at rest.
#
# (We could conceivably encrypt all data at rest, using Vault to
# encrypt the OSDs.  But Vault depends on Prometheus Operator depends on
# Rook/Ceph storage, so for now we're leaving that tangled mess
# well enough alone.  Some day we'll untangle it...)
#
echo "  Setting up Rook/Ceph S3 object storage:"
kubectl apply \
        --filename $CLUSTER_DIR/storage-rook-s3.yaml \
        --kubeconfig $KUBECONFIG \
    || exit 1

#
# Don't bother waiting for S3 storage to be ready; it should be quick,
# but by the time anyone tries to access it (e.g. Grafana Loki for
# log aggregation), it should be long since ready to go.
#

echo "SUCCESS Installing storage (Rook/Ceph)."
exit 0
