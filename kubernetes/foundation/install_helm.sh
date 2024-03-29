#!/bin/sh

#
# Source:
#
#     https://developer.hashicorp.com/vault/docs/platform/k8s/helm
#
HELM_VERSION=3.14.0

#
# Helm downloadable releases are at:
#     https://github.com/helm/helm/releases
#

echo "Installing helm version $HELM_VERSION..."

OS_KERNEL=`uname -s`
if test "$OS_KERNEL" = "Linux"
then
    echo "  OS kernel = Linux."
    HELM_OS="linux"
elif test "$OS_KERNEL" = "Darwin"
then
    echo "  OS kernel = Darwin (MacOS)."
    HELM_OS="darwin"
else
    echo "ERROR Unrecognized OS kernel: $OS_KERNEL" >&2
    exit 1
fi

CPU_ARCHITECTURE=`uname -m`
if test "$CPU_ARCHITECTURE" = "aarch64"
then
    echo "  CPU architecture = aarch64 (e.g. Raspberry Pi)."
    HELM_ARCHITECTURE="arm64"
elif test "$ARCHITECTURE" = "arm64"
then
    echo "  CPU architecture = arm64 (e.g. Mac M1)."
    HELM_ARCHITECTURE="arm64"
elif test "$CPU_ARCHITECTURE" = "ppc64le"
then
    echo "  Machine architecture = ppc64le (e.g. PowerPC)."
    HELM_ARCHITECTURE="ppc64le"
elif test "$CPU_ARCHITECTURE" = "s390x"
then
    echo "  Machine architecture = s390x (e.g. System/390)."
    HELM_ARCHITECTURE="s390x"
elif test "$CPU_ARCHITECTURE" = "x86_64"
then
    echo "  CPU architecture = x86_64 (e.g. Intel/AMD)."
    HELM_ARCHITECTURE="amd64"
else
    echo "ERROR Unrecognized CPU architecture: $CPU_ARCHITECTURE" >&2
    exit 1
fi


echo "  Checking sudo access:"
sudo echo "  Granted sudo access." \
    || exit 1

HELM_URL="https://get.helm.sh/helm-v${HELM_VERSION}-${HELM_OS}-${HELM_ARCHITECTURE}.tar.gz"

if test -d "./helm" \
        -o -f "./helm.tar.gz"
then
    echo "  Deleting existing helm download:"
    rm -rf ./helm ./helm.tar.gz \
        || exit 2
fi

echo "  Downloading helm from $HELM_URL:"
curl --location --fail-with-body --output ./helm.tar.gz "$HELM_URL" \
    || exit 3

echo "  Extracting helm from helm.tar.gz:"
mkdir -p ./helm \
    || exit 4
OLD_PWD=`pwd`
cd ./helm \
    || exit 4
tar xzf ../helm.tar.gz \
    || exit 4
cd "$OLD_PWD" \
    || exit 4
HELM_EXECUTABLE=`find ./helm/ -type f -name 'helm'`
if test $? -ne 0 \
        -o -z "$HELM_EXECUTABLE"
then
    exit 4
fi

echo "  Copying helm to /usr/local/bin/:"
sudo cp "$HELM_EXECUTABLE" /usr/local/bin/ \
    || exit 4

echo "  Making helm executable by all:"
sudo chmod a+x /usr/local/bin/helm \
    || exit 5

echo "  Removing temporary helm files:"
rm -rf ./helm ./helm.tar.gz \
    || exit 6

echo "SUCCESS Installing helm version $HELM_VERSION."
exit 0
