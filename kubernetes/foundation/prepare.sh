#!/bin/sh

RUN_DIR=`dirname $0`
FOUNDATION_DIR=`dirname $0`
KUBECONFIG=$HOME/.kube/kubeconfig-kubedemo.yaml
KUSTOMIZED_FILE=$HOME/kustomized-foundation.yaml
KUSTOMIZED_DIR=$HOME/kustomized-foundation

echo "      Preparing foundation layer Kubernetes components..."

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


echo "        Spawning extra scripts in the background:"
for BACKGROUND_SCRIPT in \
    $RUN_DIR/apply_secrets.sh \
        $RUN_DIR/apply_load_balancer.sh \
        $RUN_DIR/apply_mesh.sh
do
    LOG_FILE=`echo "$BACKGROUND_SCRIPT" \
                  | sed 's|^.*/\([^/]*\)\.sh$|\1.log|'`
    echo "          $BACKGROUND_SCRIPT (log=$LOG_FILE):"
    $BACKGROUND_SCRIPT \
        > "$LOG_FILE" \
        2>&1 \
        &
done

echo "      SUCCESS Preparing foundation layer Kubernetes components."
exit 0
