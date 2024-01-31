#!/bin/sh

echo "Installing the foundation for a Kubernetes demo..."

RUN_DIR=`dirname $0`

echo "  Checking sudo access:"
sudo echo "  Granted sudo access." \
    || exit 1


$RUN_DIR/foundation/install_docker.sh \
    || exit 2

$RUN_DIR/foundation/install_kind.sh \
    || exit 2

$RUN_DIR/foundation/install_kubectl.sh \
    || exit 2

$RUN_DIR/foundation/install_kustomize.sh \
    || exit 2

echo "SUCCESS Installing the foundation for a Kubernetes demo."
exit 0
