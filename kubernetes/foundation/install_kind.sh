#!/bin/sh

KIND_VERSION=0.20.0

echo "Installing kind (Kubernetes in Docker) version $KIND_VERSION..."

OS_KERNEL=`uname -s`
if test "$OS_KERNEL" = "Linux"
then
    echo "  OS kernel = Linux."
    KIND_OS="linux"
elif test "$OS_KERNEL" = "Darwin"
then
    echo "  OS kernel = Darwin (MacOS)."
    KIND_OS="darwin"
else
    echo "ERROR Unrecognized OS kernel: $OS_KERNEL" >&2
    exit 1
fi

CPU_ARCHITECTURE=`uname -m`
if test "$CPU_ARCHITECTURE" = "aarch64"
then
    echo "  CPU architecture = aarch64 (e.g. Raspberry Pi)."
    KIND_ARCHITECTURE="arm64"
elif test "$ARCHITECTURE" = "arm64"
then
    echo "  CPU architecture = arm64 (e.g. Mac M1)."
    KIND_ARCHITECTURE="arm64"
elif test "$CPU_ARCHITECTURE" = "ppc64le"
then
    echo "  Machine architecture = ppc64le (e.g. PowerPC)."
    KIND_ARCHITECTURE="ppc64le"
elif test "$CPU_ARCHITECTURE" = "s390x"
then
    echo "  Machine architecture = s390x (e.g. System/390)."
    KIND_ARCHITECTURE="s390x"
elif test "$CPU_ARCHITECTURE" = "x86_64"
then
    echo "  CPU architecture = x86_64 (e.g. Intel/AMD)."
    KIND_ARCHITECTURE="amd64"
else
    echo "ERROR Unrecognized CPU architecture: $CPU_ARCHITECTURE" >&2
    exit 1
fi


echo "  Checking sudo access:"
sudo echo "  Granted sudo access." \
    || exit 1

#
# kind downloadable releases are at:
#
#     https://github.com/kubernetes-sigs/kind/releases
#
KIND_URL="https://github.com/kubernetes-sigs/kind/releases/download/v${KIND_VERSION}/kind-${KIND_OS}-${KIND_ARCHITECTURE}"

if test -f "./kind"
then
    echo "  Deleting existing kind download:"
    rm -f ./kind \
        || exit 2
fi

echo "  Downloading kind from $KIND_URL:"
curl --location --fail-with-body --output ./kind "$KIND_URL" \
    || exit 3

echo "  Moving kind to /usr/local/bin/:"
sudo mv ./kind /usr/local/bin/ \
    || exit 4

echo "  Making kind executable by all:"
sudo chmod a+x /usr/local/bin/kind \
    || exit 5

echo "SUCCESS Installing kind (Kubernetes in Docker) version $KIND_VERSION."
exit 0
