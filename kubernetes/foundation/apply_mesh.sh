#!/bin/sh

#
# Istio install instructions:
#
#     https://istio.io/latest/docs/setup/getting-started/#install
#
# Note that istioctl was already installed separately
# (see install_istioctl.sh).
#

ISTIO_VERSION=1.20.3
ISTIO_PROFILE=default

echo "Applying service mesh (Istio)..."

FOUNDATION_DIR=`dirname $0`
KUBECONFIG=$HOME/.kube/kubeconfig-kubedemo.yaml

echo "  Installing Istio profile: $ISTIO_PROFILE"
istioctl install \
         --filename $FOUNDATION_DIR/mesh/istio/mesh-istio-profile.yaml \
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

echo "SUCCESS Applying service mesh (Istio)."
exit 0
