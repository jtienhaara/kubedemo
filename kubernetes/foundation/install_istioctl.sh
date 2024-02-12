#!/bin/sh

#
# Istio 1.20.3 is available from:
#
#     https://github.com/istio/istio/releases
#
# Istio is licensed under the Apache 2.0 license:
#
#     https://github.com/istio/istio/blob/1.20.3/LICENSE
#
# Preferred install method these days is istioctl.  Instructions:
#
#     https://istio.io/latest/docs/setup/install/istioctl/
#
# Kubernetes best practices with Istio:
#
#     https://istio.io/latest/docs/ops/deployment/requirements/
#

ISTIO_VERSION=1.20.3

echo "Installing Istio service mesh version $ISTIO_VERSION..."

OS_KERNEL=`uname -s`
if test "$OS_KERNEL" = "Linux"
then
    echo "  OS kernel = Linux."
    ISTIO_OS="linux"
elif test "$OS_KERNEL" = "Darwin"
then
    echo "  OS kernel = Darwin (MacOS)."
    ISTIO_OS="darwin"
else
    echo "ERROR Unrecognized OS kernel: $OS_KERNEL" >&2
    exit 1
fi

CPU_ARCHITECTURE=`uname -m`
if test "$CPU_ARCHITECTURE" = "aarch64"
then
    echo "  CPU architecture = aarch64 (e.g. Raspberry Pi)."
    ISTIO_ARCHITECTURE="arm64"
elif test "$ARCHITECTURE" = "arm64"
then
    echo "  CPU architecture = arm64 (e.g. Mac M1)."
    ISTIO_ARCHITECTURE="arm64"
elif test "$CPU_ARCHITECTURE" = "ppc64le"
then
    echo "  Machine architecture = ppc64le (e.g. PowerPC)."
    ISTIO_ARCHITECTURE="ppc64le"
elif test "$CPU_ARCHITECTURE" = "s390x"
then
    echo "  Machine architecture = s390x (e.g. System/390)."
    ISTIO_ARCHITECTURE="s390x"
elif test "$CPU_ARCHITECTURE" = "x86_64"
then
    echo "  CPU architecture = x86_64 (e.g. Intel/AMD)."
    ISTIO_ARCHITECTURE="amd64"
else
    echo "ERROR Unrecognized CPU architecture: $CPU_ARCHITECTURE" >&2
    exit 1
fi


echo "  Checking sudo access:"
sudo echo "  Granted sudo access." \
    || exit 1

ISTIO_URL="https://github.com/istio/istio/releases/download/${ISTIO_VERSION}/istio-${ISTIO_VERSION}-${ISTIO_OS}-${ISTIO_ARCHITECTURE}.tar.gz"

if test -d "./istio" \
        -o -f "./istio.tar.gz"
then
    echo "  Deleting existing istio download:"
    rm -rf ./istio ./istio.tar.gz \
        || exit 2
fi

echo "  Downloading istio from $ISTIO_URL:"
curl --location --fail-with-body --output ./istio.tar.gz "$ISTIO_URL" \
    || exit 3

echo "  Extracting istioctl from istio.tar.gz:"
mkdir -p ./istio \
    || exit 4
OLD_PWD=`pwd`
cd ./istio \
    || exit 4
tar xzf ../istio.tar.gz \
    || exit 4
cd "$OLD_PWD" \
    || exit 4
ISTIOCTL_EXECUTABLE=`find ./istio/ -type f -name 'istioctl'`
if test $? -ne 0 \
        -o -z "$ISTIOCTL_EXECUTABLE"
then
    exit 4
fi

echo "  Moving $ISTIOCTL_EXECUTABLE to /usr/local/bin/:"
sudo mv $ISTIOCTL_EXECUTABLE /usr/local/bin/ \
    || exit 4

echo "  Making istioctl executable by all:"
sudo chmod a+x /usr/local/bin/istioctl \
    || exit 5

echo "  Removing temporary istio files:"
rm -rf ./istio ./istio.tar.gz \
    || exit 6

echo "SUCCESS Installing Istio service mesh version $ISTIO_VERSION."
exit 0
