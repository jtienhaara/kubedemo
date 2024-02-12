#!/bin/sh

#
# Istio install instructions:
#
#     https://istio.io/latest/docs/setup/getting-started/#install
#

ISTIO_PROFILE=default

echo "Applying service mesh (Istio)..."

CLUSTER_DIR=/cloud-init/kubernetes/foundation/cluster
KUBECONFIG=$HOME/.kube/kubeconfig-kubedemo.yaml

echo "  Installing Istio profile: $ISTIO_PROFILE"
istioctl install \
         --set profile=$ISTIO_PROFILE \
         --skip-confirmation \
         --kubeconfig $KUBECONFIG \
    || exit 1

echo "  Waiting for Istio mesh to finish installing CRDs:"
kubectl wait \
	--for condition=Established \
	--all CustomResourceDefinition \
	--namespace istio-system \
        --kubeconfig $KUBECONFIG \
    || exit 1

echo "  Applying Gateway to expose web UIs..."
kubectl apply \
        --filename $CLUSTER_DIR/mesh-istio-gateway.yaml \
        --kubeconfig $KUBECONFIG \
    || exit 1

echo "  Applying VirtualServices to expose web UIs..."
for VIRTUAL_SERVICE in \
    $CLUSTER_DIR/observability-virtual-services.yaml
do
    echo "    Applying VirtualService: $VIRTUAL_SERVICE"
    kubectl apply \
            --filename "$VIRTUAL_SERVICE" \
            --kubeconfig $KUBECONFIG \
        || exit 1
done

echo "SUCCESS Applying service mesh (Istio)."
exit 0
