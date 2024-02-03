#!/bin/sh

KUSTOMIZE_VERSION=5.3.0

#
# kustomize download instructions are at:
#
#     https://kubectl.docs.kubernetes.io/installation/kustomize/
#
# And the releases are listed at:
#
#     https://github.com/kubernetes-sigs/kustomize/releases
#

echo "Installing kustomize version $KUSTOMIZE_VERSION..."

OS_KERNEL=`uname -s`
if test "$OS_KERNEL" = "Linux"
then
    echo "  Operating system = Linux."
    KUSTOMIZE_OS="linux"
elif test "$OS_KERNEL" = "Darwin"
then
    echo "  Operating system = Darwin (MacOS)."
    KUSTOMIZE_OS="darwin"
else
    echo "ERROR Unrecognized OS kernel: $OS_KERNEL" >&2
    exit 1
fi

CPU_ARCHITECTURE=`uname -m`
if test "$CPU_ARCHITECTURE" = "aarch64"
then
    echo "  Machine architecture = aarch64 (e.g. Raspberry Pi)."
    KUSTOMIZE_ARCHITECTURE="arm64"
elif test "$CPU_ARCHITECTURE" = "arm64"
then
    echo "  Machine architecture = arm64 (e.g. Mac M1)."
    KUSTOMIZE_ARCHITECTURE="arm64"
elif test "$CPU_ARCHITECTURE" = "ppc64le"
then
    echo "  Machine architecture = ppc64le (e.g. PowerPC)."
    KUSTOMIZE_ARCHITECTURE="ppc64le"
elif test "$CPU_ARCHITECTURE" = "s390x"
then
    echo "  Machine architecture = s390x (e.g. System/390)."
    KUSTOMIZE_ARCHITECTURE="s390x"
elif test "$CPU_ARCHITECTURE" = "x86_64"
then
    echo "  Machine architecture = x86_64 (e.g. Intel/AMD)."
    KUSTOMIZE_ARCHITECTURE="amd64"
else
    echo "ERROR Unrecognized CPU architecture: $CPU_ARCHITECTURE" >&2
    exit 1
fi


echo "  Checking sudo access:"
sudo echo "  Granted sudo access." \
    || exit 1

KUSTOMIZE_URL="https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv${KUSTOMIZE_VERSION}/kustomize_v${KUSTOMIZE_VERSION}_${KUSTOMIZE_OS}_${KUSTOMIZE_ARCHITECTURE}.tar.gz"

if test -f "./kustomize" \
        -o -f "./kustomize.tar.gz"
then
    echo "  Deleting existing kustomize download:"
    rm -f ./kustomize ./kustomize.tar.gz \
        || exit 2
fi

echo "  Downloading kustomize from $KUSTOMIZE_URL:"
curl --location --fail-with-body --output ./kustomize.tar.gz "$KUSTOMIZE_URL" \
    || exit 3

echo "  Extracting kustomize from gzipped tarball:"
tar xf kustomize.tar.gz \
    || exit 4
rm -f kustomize.tar.gz \
    || exit 5

echo "  Moving kustomize to /usr/local/bin/:"
sudo mv ./kustomize /usr/local/bin/ \
    || exit 6

echo "  Making kustomize executable by all:"
sudo chmod a+x /usr/local/bin/kustomize \
    || exit 7

echo "SUCCESS Installing kustomize version $KUSTOMIZE_VERSION."
exit 0
