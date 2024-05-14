#!/bin/sh

#
# kube-prometheus for base observability (metrics, dashboards and alerting).
#
# (N.b. Required before Vault secrets is installed.)
#
# kube-prometheus version 0.13.0 was git cloned and copied here:
#
#     https://github.com/prometheus-operator/kube-prometheus/releases
#     https://github.com/prometheus-operator/kube-prometheus/releases/tag/v0.13.0
#
# No official support yet for Kubernetes 1.29 (only up to 1.28):
#
#     https://github.com/prometheus-operator/kube-prometheus/tree/v0.13.0
#
# kube-prometheus is licensed under the Apache License 2.0 license:
#
#     https://github.com/prometheus-operator/kube-prometheus/blob/release-0.13/LICENSE
#

KUBE_PROMETHEUS_VERSION=0.13.0

echo "Installing observability (kube-prometheus)..."

CLUSTER_DIR=/cloud-init/kubernetes/foundation/cluster
KUBECONFIG=$HOME/.kube/kubeconfig-kubedemo.yaml

#
# From the kube-prometheus README:
#
#     Create the namespace and CRDs, and then wait for them to be
#     available before creating the remaining resources
#     Note that due to some CRD size we are using kubectl server-side apply
#     feature which is generally available since kubernetes 1.22.
#     If you are using previous kubernetes versions this feature may not
#     be available and you would need to use kubectl create instead.
#
# Unfortunately we have no choice but to use kubectl create.
# No matter what options we add to kubectl apply, it always generates:
#
#     Resource: "apiextensions.k8s.io/v1, Resource=customresourcedefinitions",
#     GroupVersionKind: "apiextensions.k8s.io/v1, Kind=CustomResourceDefinition"
#     Name: "prometheusagents.monitoring.coreos.com", Namespace: ""
#     for: "/cloud-init/kubernetes/foundation/cluster/observability/setup/
#     0prometheusagentCustomResourceDefinition.yaml": error when patching
#     "/cloud-init/kubernetes/foundation/cluster/observability/setup/
#     0prometheusagentCustomResourceDefinition.yaml":
#     CustomResourceDefinition.apiextensions.k8s.io
#     "prometheusagents.monitoring.coreos.com" is invalid:
#     metadata.annotations: Too long: must have at most 262144 bytes
#
# So we modified setup/0prometheusagentCustomResourceDefinition.yaml
# from the original by replacing description: ...
# with description: 'REDACTED', so that kubectl apply --server-side
# or kubectl create will work with kind (otherwise we exceed
# the 262144 byte metadata.annotations limit, which probably
# does not happen with other Kubernetes distributions???).
#
echo "  Installing kube-prometheus setup:"
kubectl apply --server-side=true \
        --filename $CLUSTER_DIR/observability/setup/ \
        --kubeconfig $KUBECONFIG \
    || exit 1

echo "  Waiting for kube-prometheus setup to finish installing CRDs:"
kubectl wait \
	--for condition=Established \
	--all CustomResourceDefinition \
	--namespace monitoring \
        --kubeconfig $KUBECONFIG \
    || exit 1

echo "  Installing kube-prometheus observability resources:"
kubectl apply \
        --filename $CLUSTER_DIR/observability/ \
        --kubeconfig $KUBECONFIG \
    || exit 1

#
# We've already waited for the CRDs to be created.
# We don't need to wait for the containers to spin up -- there are lots
# of them!
#

echo "SUCCESS Installing observability (kube-prometheus)."
exit 0
