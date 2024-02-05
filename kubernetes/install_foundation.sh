#!/bin/sh

echo "Installing the foundation for a Kubernetes demo..."

RUN_DIR=`dirname $0`

echo "  Checking sudo access:"
sudo echo "  Granted sudo access." \
    || exit 1

echo "  Installing tools:"

echo "    Installing docker:"
sudo $RUN_DIR/foundation/install_docker.sh \
    || exit 2

echo "    Installing kind:"
sudo $RUN_DIR/foundation/install_kind.sh \
    || exit 2

echo "    Installing kubectl:"
sudo $RUN_DIR/foundation/install_kubectl.sh \
    || exit 2

echo "    Installing kustomize:"
sudo $RUN_DIR/foundation/install_kustomize.sh \
    || exit 2

echo "    Installing helm:"
sudo $RUN_DIR/foundation/install_helm.sh \
    || exit 2


echo "  Configuring OS:"

echo "    Setting limits:"
$RUN_DIR/foundation/os_limits.sh \
    || exit 3


echo "  Creating cluster:"

echo "    Creating \"kubedemo\" cluster:"
$RUN_DIR/foundation/create_cluster.sh \
    || exit 4

echo "    Applying storage (Rook/Ceph) to \"kubedemo\" cluster:"
$RUN_DIR/foundation/apply_storage.sh \
    || exit 4

echo "    Applying observability (kube-prometheus) to \"kubedemo\" cluster:"
$RUN_DIR/foundation/apply_observability.sh \
    || exit 4

echo "    Applying secrets (HashiCorp Vault) to \"kubedemo\" cluster:"
$RUN_DIR/foundation/apply_secrets.sh \
    || exit 4

echo "SUCCESS Installing the foundation for a Kubernetes demo."
exit 0
