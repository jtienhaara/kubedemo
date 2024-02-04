#!/bin/sh

#
# Creates the "kubedemo" cluster.
#
echo "Creating \"kubedemo\" cluster..."

CLUSTER_DIR=/cloud-init/kubernetes/foundation/cluster
KUBECONFIG=$HOME/.kube/kubeconfig-kubedemo.yaml

#
# 1 control-plane node, 3 worker nodes:
#
NUM_NODES=4

echo "  Ensuring ~/.kube directory:"
mkdir -p ~/.kube \
    || exit 1

echo "  Increasing ulimit / NOFILES to 65536 for kind / Docker:"
sudo sed -i.ORIGINAL \
     's|^#DefaultLimitNOFILE=.*$|DefaultLimitNOFILE=65536:524288|' \
     /etc/systemd/system.conf \
    || exit 1
ulimit -n 65536 \
    || exit 1

echo "  Creating \"kubedemo\" kind cluster ($KUBECONFIG):"
kind create cluster \
     --config $CLUSTER_DIR/cluster-kind.yaml \
     --kubeconfig $KUBECONFIG
EXIT_CODE=$?
if test $EXIT_CODE -ne 0
then
    # kind frequently fails on the first try inside this VM.  :(
    echo "    Retrying to create \"kubedemo\" kind cluster:"
    kind create cluster \
         --config $CLUSTER_DIR/cluster-kind.yaml \
         --kubeconfig $KUBECONFIG \
        || exit 1
fi

echo "  Waiting until cluster is happy (nodes Ready, /readyz succeeds):"
MAX_SECONDS=30
SLEEP_SECONDS=5
TOTAL_SECONDS=0
while test $TOTAL_SECONDS -lt $MAX_SECONDS
do
    KUBERNETES_READY=`kubectl get --raw='/readyz?verbose' \
                          --kubeconfig $KUBECONFIG \
                          2>&1`
    if test $? -ne 0
    then
        if test $TOTAL_SECONDS -eq 0
        then
            echo "    Kubernetes is not ready yet:"
            echo "$KUBERNETES_READY" \
                | sed 's|^\(.*\)$|      \1|'
        else
            echo "      ..."
        fi
        sleep $SLEEP_SECONDS
        NEW_TOTAL_SECONDS=`expr $TOTAL_SECONDS + $SLEEP_SECONDS`
        TOTAL_SECONDS=$NEW_TOTAL_SECONDS
        continue
    fi

    NODES_NOT_READY=`kubectl get nodes \
                         --kubeconfig $KUBECONFIG \
                         | awk '$2 != "STATUS" && $2 != "Ready" { print $0; }' \
                         2>&1`
    if test $? -ne 0 \
            -o ! -z "$NODES_NOT_READY"
    then
        if test $TOTAL_SECONDS -eq 0
        then
            echo "    Nodes are not all ready yet:"
            echo "$NODES_NOT_READY" \
                | sed 's|^\(.*\)$|      \1|'
        else
            echo "      ..."
        fi
        sleep $SLEEP_SECONDS
        NEW_TOTAL_SECONDS=`expr $TOTAL_SECONDS + $SLEEP_SECONDS`
        TOTAL_SECONDS=$NEW_TOTAL_SECONDS
        continue
    fi

    NUM_NODES_READY=`kubectl get nodes \
                         --kubeconfig $KUBECONFIG \
                         | awk '$2 == "Ready" { print $0; }' \
                         | wc -l \
                         2>&1`
    if test $? -ne 0 \
            -o "$NUM_NODES_READY" != "$NUM_NODES"
    then
        if test $TOTAL_SECONDS -eq 0
        then
            echo "    Not all $NUM_NODES nodes are up yet: $NUM_NODES_READY"
        else
            echo "      ..."
        fi
        sleep $SLEEP_SECONDS
        NEW_TOTAL_SECONDS=`expr $TOTAL_SECONDS + $SLEEP_SECONDS`
        TOTAL_SECONDS=$NEW_TOTAL_SECONDS
        continue
    fi

    echo "$KUBERNETES_READY" \
        | sed 's|^\(.*\)$|      \1|'

    echo "    Kubernetes is ready now."
    break
done

if test $TOTAL_SECONDS -ge $MAX_SECONDS
then
    echo "ERROR Kubernetes still isn't ready after $TOTAL_SECONDS" >&2
    exit 1
fi

echo "SUCCESS Creating \"kubedemo\" cluster..."
exit 0
