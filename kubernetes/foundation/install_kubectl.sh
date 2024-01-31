#!/bin/sh

KUBECTL_VERSION=1.29.1

echo "Installing kubectl (\"cube cuddle\") version $KUBECTL_VERSION..."

OS_KERNEL=`uname -s`
if test "$OS_KERNEL" = "Linux"
then
    echo "  Operating system = Linux."
    KUBECTL_OS="linux"
elif test "$OS_KERNEL" = "Darwin"
then
    echo "  Operating system = Darwin (MacOS)."
    KUBECTL_OS="darwin"
else
    echo "ERROR Unrecognized OS kernel: $OS_KERNEL" >&2
    exit 1
fi

CPU_ARCHITECTURE=`uname -m`
if test "$CPU_ARCHITECTURE" = "aarch64"
then
    echo "  Machine architecture = aarch64 (e.g. Raspberry Pi)."
    KUBECTL_ARCHITECTURE="arm64"
elif test "$CPU_ARCHITECTURE" = "arm64"
then
    echo "  Machine architecture = arm64 (e.g. Mac M1)."
    KUBECTL_ARCHITECTURE="arm64"
elif test "$CPU_ARCHITECTURE" = "ppc64le"
then
    echo "  Machine architecture = ppc64le (e.g. PowerPC)."
    KUBECTL_ARCHITECTURE="ppc64le"
elif test "$CPU_ARCHITECTURE" = "s390x"
then
    echo "  Machine architecture = s390x (e.g. System/390)."
    KUBECTL_ARCHITECTURE="s390x"
elif test "$CPU_ARCHITECTURE" = "x86_64"
then
    echo "  Machine architecture = x86_64 (e.g. Intel/AMD)."
    KUBECTL_ARCHITECTURE="amd64"
else
    echo "ERROR Unrecognized CPU architecture: $CPU_ARCHITECTURE" >&2
    exit 1
fi


echo "  Checking sudo access:"
sudo echo "  Granted sudo access." \
    || exit 1


#
# kubectl download instructions are at:
#
#     https://kubernetes.io/docs/tasks/tools/#kubectl
#
# And the current stable release is referenced at:
#
#     https://dl.k8s.io/release/stable.txt
#
KUBECTL_URL="https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/${KUBECTL_OS}/${KUBECTL_ARCHITECTURE}/kubectl"

if test -f "./kubectl"
then
    echo "  Deleting existing kubectl download:"
    rm -f ./kubectl \
        || exit 2
fi

echo "  Downloading kubectl from $KUBECTL_URL:"
curl --location --fail-with-body --output ./kubectl "$KUBECTL_URL" \
    || exit 3

echo "  Moving kubectl to /usr/local/bin/:"
sudo mv ./kubectl /usr/local/bin/ \
    || exit 4

echo "  Making kubectl executable by all:"
sudo chmod a+x /usr/local/bin/kubectl \
    || exit 5

echo "SUCCESS Installing kubectl (\"cube cuddle\") version $KUBECTL_VERSION."
exit 0
