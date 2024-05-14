#!/bin/sh

echo "Installing the foundation for a Kubernetes demo..."

RUN_DIR=`dirname $0`

export DEBIAN_FRONTEND=noninteractive

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

#
# kubectl-slice:
#
#     https://github.com/patrickdappollonio/kubectl-slice
#
# MIT license:
#
#     https://github.com/patrickdappollonio/kubectl-slice/blob/main/LICENSE
#
echo "    Installing kubectl-slice:"
# !!! TODO don't assume x86/64 architecture:
wget https://github.com/patrickdappollonio/kubectl-slice/releases/download/v1.2.9/kubectl-slice_linux_x86_64.tar.gz \
    || exit 1
tar xvzf kubectl-slice_linux_x86_64.tar.gz \
    || exit 1
sudo mv kubectl-slice /usr/local/bin/ \
    || exit 1
kubectl-slice --help \
              > /dev/null \
    || exit 1

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

echo "    Preparing foundation layer manifests and launching bg scripts:"
$RUN_DIR/foundation/prepare.sh \
    || exit 5

echo "    Applying foundation layer manifests:"
$RUN_DIR/foundation/apply.sh \
    || exit 5


echo "  Finalizing VM setup:"

echo "    Reverse proxying HTTP port 8080 from VM to kubedemo LoadBalancer:"
$RUN_DIR/foundation/vm_reverse_proxy.sh \
    || exit 6


echo "  Integrating foundation components:"

echo "    Integrating secrets with apps:"
$RUN_DIR/foundation/integrate_secrets.sh \
    || exit 7


echo "SUCCESS Installing the foundation for a Kubernetes demo."
exit 0
