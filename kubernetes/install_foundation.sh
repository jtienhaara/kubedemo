#!/bin/sh

echo "Installing the foundation for a Kubernetes demo..."

RUN_DIR=`dirname $0`

echo "  Checking sudo access:"
sudo echo "  Granted sudo access." \
    || exit 1

echo "  Installing software:"

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

echo "    Installing istioctl:"
sudo $RUN_DIR/foundation/install_istioctl.sh \
    || exit 2


echo "  Installing troubleshooting tools:"

echo "    Installing networking tools:"
$RUN_DIR/foundation/tools_networking.sh \
    || exit 3


echo "  Configuring OS:"

echo "    Setting limits:"
$RUN_DIR/foundation/os_limits.sh \
    || exit 4


echo "  Creating cluster:"

echo "    Creating \"kubedemo\" cluster:"
$RUN_DIR/foundation/create_cluster.sh \
    || exit 5

echo "    Applying storage (Rook/Ceph) to \"kubedemo\" cluster:"
$RUN_DIR/foundation/apply_storage.sh \
    || exit 5

echo "    Applying observability (kube-prometheus) to \"kubedemo\" cluster:"
$RUN_DIR/foundation/apply_observability.sh \
    || exit 5

echo "    Applying certificates (cert-manager) to \"kubedemo\" cluster:"
$RUN_DIR/foundation/apply_certificates.sh \
    || exit 5

echo "    Applying secrets (HashiCorp Vault) to \"kubedemo\" cluster:"
$RUN_DIR/foundation/apply_secrets.sh \
    || exit 5

echo "    Applying load balancer (MetalLB) to \"kubedemo\" cluster:"
$RUN_DIR/foundation/apply_load_balancer.sh \
    || exit 5

echo "    Applying mesh (Istio) to \"kubedemo\" cluster:"
$RUN_DIR/foundation/apply_mesh.sh \
    || exit 5


echo "  Finalizing VM setup:"

echo "    Forwarding HTTP port 80 from VM to kubedemo LoadBalancer:"
$RUN_DIR/foundation/vm_forward_ports.sh \
    || exit 5


echo "SUCCESS Installing the foundation for a Kubernetes demo."
exit 0
