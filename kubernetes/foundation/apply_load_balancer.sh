#!/bin/sh

#
# MetalLB version 0.14.3 for Kubernetes load balancer is from:
#
#     https://github.com/metallb/metallb/releases
#
# MetalLB is licensed under the Apache 2.0 license:
#
#     https://github.com/metallb/metallb/blob/v0.14.3/LICENSE
#

METALLB_VERSION=0.14.3

#
# Installing MetalLB + kind instructions:
#
#     https://kind.sigs.k8s.io/docs/user/loadbalancer/
#

echo "Installing load balancer (MetalLB)..."

CLUSTER_DIR=/cloud-init/kubernetes/foundation/cluster
KUBECONFIG=$HOME/.kube/kubeconfig-kubedemo.yaml

# The docker network appears to be always named "kind", regardless
# of what the cluster is called...  Does this mean multiple clusters
# share the same network?  (Untested.)
KIND_NETWORK_NAME=kind

echo "  Applying MetalLB resources to Kubernetes cluster:"
kubectl apply \
        --filename $CLUSTER_DIR/load-balancer-metallb-resources.yaml \
        --kubeconfig $KUBECONFIG \
    || exit 1

echo "  Waiting for MetalLB Kubernetes resources to be ready:"
kubectl wait \
        pod \
        --for=condition=Ready \
        --selector=app=metallb \
        --namespace metallb-system \
        --timeout=90s \
        --kubeconfig $KUBECONFIG \
    || exit 1

#
# Example output:
#
#     [{172.18.0.0/16  172.18.0.1 map[]} {fc00:f853:ccd:e793::/64   map[]}]
#
echo "  Retrieving Docker network CIDR for use by MetalLB:"
KIND_NETWORK_MAPS=`docker network inspect \
                       --format '{{.IPAM.Config}}' \
                       $KIND_NETWORK_NAME`
EXIT_CODE=$?
if test -z "$KIND_NETWORK_MAPS" \
        -o $EXIT_CODE -ne 0
then
    echo "ERROR Could not retrieve kind network maps: \"$KIND_NETWORK_MAPS\"" >&2
    exit 1
fi

KIND_IP4_CIDR=`echo "$KIND_NETWORK_MAPS" \
                   | sed 's|^.*{\([1-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*/[1-9][0-9]*\) .*$|\1|'`
EXIT_CODE=$?
if test -z "$KIND_IP4_CIDR" \
        -o $EXIT_CODE -ne 0
then
    echo "ERROR Could not determine kind IPv4 CIDR from \"$KIND_NETWORK_MAPS\": \"$KIND_IP4_CIDR\"" >&2
    exit 1
fi

echo "  Restricting CIDR $KIND_IP4_CIDR for MetalLB use:"
KIND_CIDR_ADDRESS=`echo "$KIND_IP4_CIDR" \
                       | sed 's|^\(.*\)/.*$|\1|'`
KIND_CIDR_PREFIX=`echo "$KIND_IP4_CIDR" \
                      | sed 's|^.*/\([1-9][0-9]*\)$|\1|'`
if test -z "$KIND_CIDR_ADDRESS" \
        -o -z "$KIND_CIDR_PREFIX"
then
    echo "ERROR Determining KIND_CIDR_ADDRESS ($KIND_CIDR_ADDRESS) and/or KIND_CIDR_PREFIX ($KIND_CIDR_PREFIX) from: $KIND_IP4_CIDR" >&2
    exit 1
fi

if test $KIND_CIDR_PREFIX -ge 28
then
    echo "ERROR With Docker kind network CIDR \"$KIND_IP4_CIDR\" prefix = $KIND_CIDR_PREFIX there are not enough IP addresses (<= 16) for MetalLB to co-exist peacefully with the cluster" >&2
    exit 1
fi

METALLB_ADDRESS=`echo "$KIND_CIDR_ADDRESS" \
                     | sed 's|^\([1-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\)\.[0-9][0-9]*$|\1.128|'`
METALLB_PREFIX=28
if test -z "$METALLB_ADDRESS"
then
    echo "ERROR Could not determine a .128 IPv4 address from $KIND_CIDR_ADDRESS: \"$METALLB_ADDRESS\"" >&2
    exit 1
fi

METALLB_CIDR="$METALLB_ADDRESS/$METALLB_PREFIX"

#
# MetalLB configuration:
#
#     https://metallb.universe.tf/configuration/
#
METALLB_IP_ADDRESS_POOL_YAML="$HOME/metallb_ip_address_pool.yaml"
cat -- > "$METALLB_IP_ADDRESS_POOL_YAML" << END_OF_METALLB_CONFIGURATION_YAML
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: kubedemo
  namespace: metallb-system
spec:
  addresses:
  - $METALLB_CIDR
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: kubedemo
  namespace: metallb-system
END_OF_METALLB_CONFIGURATION_YAML
EXIT_CODE=$?
if test $EXIT_CODE -ne 0 \
        -o ! -f "$METALLB_IP_ADDRESS_POOL_YAML"
then
    echo "ERROR Could not create file $METALLB_IP_ADDRESS_POOL_YAML with MetalLB IP address pool $METALLB_CIDR" >&2
    exit 1
fi

echo "  Applying MetalLB IP address pool $METALLB_CIDR from file $METALLB_IP_ADDRESS_POOL_YAML:"
kubectl apply \
        --filename "$METALLB_IP_ADDRESS_POOL_YAML" \
        --kubeconfig $KUBECONFIG \
    || exit 1

echo "SUCCESS Installing load balancer (MetalLB)."
exit 0
