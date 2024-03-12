#!/bin/sh

echo "Installing the foundation for a Kubernetes demo..."

RUN_DIR=`dirname $0`

echo "  Checking sudo access:"
sudo echo "  Granted sudo access." \
    || exit 1

echo "  Installing software:"

echo "    Updating apt:"
sudo apt-get update \
    || exit 2

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

echo "    Installing sops:"
sudo $RUN_DIR/foundation/install_sops.sh \
    || exit 2


echo "  Installing troubleshooting tools:"

echo "    Installing networking tools:"
$RUN_DIR/foundation/tools_networking.sh \
    || exit 3

echo "    Installing data tools:"
$RUN_DIR/foundation/tools_data.sh \
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

echo "    Unsealing secrets (HashiCorp Vault):"
$RUN_DIR/foundation/unseal_secrets.sh \
    || exit 5

echo "    Applying load balancer (MetalLB) to \"kubedemo\" cluster:"
$RUN_DIR/foundation/apply_load_balancer.sh \
    || exit 5

echo "    Applying mesh (Istio) to \"kubedemo\" cluster:"
$RUN_DIR/foundation/apply_mesh.sh \
    || exit 5

echo "    Applying log aggregation (Grafana Loki) to \"kubedemo\" cluster:"
$RUN_DIR/foundation/apply_logging.sh \
    || exit 5

echo "    Applying authentication (Ory Oathkeeper) to \"kubedemo\" cluster:"
$RUN_DIR/foundation/apply_authentication.sh \
    || exit 5


echo "  Finalizing VM setup:"

echo "    Reverse proxying HTTP port 8080 from VM to kubedemo LoadBalancer:"
$RUN_DIR/foundation/vm_reverse_proxy.sh \
    || exit 6


echo "  Integrating foundation components:"

echo "    Integrating observability with apps:"
$RUN_DIR/foundation/integrate_observability.sh \
    || exit 7

echo "    Integrating secrets with apps:"
$RUN_DIR/foundation/integrate_secrets.sh \
    || exit 7


echo "SUCCESS Installing the foundation for a Kubernetes demo."
exit 0
