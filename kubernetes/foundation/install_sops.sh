#!/bin/sh

SOPS_VERSION=3.8.1
AGE_VERSION=1.1.1

#
# Mozilla SOPS for encryption using AGE:
#
#     https://github.com/getsops/sops
#     https://github.com/getsops/sops/releases/tag/v3.8.1
#     https://github.com/FiloSottile/age
#     https://github.com/FiloSottile/age/releases/tag/v1.1.1
#
# SOPS is licensed under the Mozilla Public License 2.0:
#
#     https://github.com/getsops/sops/blob/main/LICENSE
#
# AGE is licensed under the BSD license:
#
#     https://github.com/FiloSottile/age/blob/main/LICENSE
#

echo "Installing sops version $SOPS_VERSION..."

OS_KERNEL=`uname -s`
if test "$OS_KERNEL" = "Linux"
then
    echo "  Operating system = Linux."
    SOPS_OS="linux"
elif test "$OS_KERNEL" = "Darwin"
then
    echo "  Operating system = Darwin (MacOS)."
    SOPS_OS="darwin"
else
    echo "ERROR Unrecognized OS kernel: $OS_KERNEL" >&2
    exit 1
fi

CPU_ARCHITECTURE=`uname -m`
if test "$CPU_ARCHITECTURE" = "aarch64"
then
    echo "  Machine architecture = aarch64 (e.g. Raspberry Pi)."
    SOPS_ARCHITECTURE="arm64"
elif test "$CPU_ARCHITECTURE" = "arm64"
then
    echo "  Machine architecture = arm64 (e.g. Mac M1)."
    SOPS_ARCHITECTURE="arm64"
elif test "$CPU_ARCHITECTURE" = "ppc64le"
then
    echo "  Machine architecture = ppc64le (e.g. PowerPC)."
    SOPS_ARCHITECTURE="ppc64le"
elif test "$CPU_ARCHITECTURE" = "s390x"
then
    echo "  Machine architecture = s390x (e.g. System/390)."
    SOPS_ARCHITECTURE="s390x"
elif test "$CPU_ARCHITECTURE" = "x86_64"
then
    echo "  Machine architecture = x86_64 (e.g. Intel/AMD)."
    SOPS_ARCHITECTURE="amd64"
else
    echo "ERROR Unrecognized CPU architecture: $CPU_ARCHITECTURE" >&2
    exit 1
fi


echo "  Checking sudo access:"
sudo echo "  Granted sudo access." \
    || exit 1

#
# Debian 12 includes age version 1.1.1:
#
echo "  Installing age encryption and ca-certificates for sops:"
sudo apt-get install -y \
     age \
     ca-certificates \
    || exit 1

SOPS_URL="https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.${SOPS_OS}.${SOPS_ARCHITECTURE}"

if test -f "./sops"
then
    echo "  Deleting existing sops download:"
    rm -f ./sops \
        || exit 2
fi

echo "  Downloading sops from $SOPS_URL:"
curl --location --fail-with-body --output ./sops "$SOPS_URL" \
    || exit 3

echo "  Moving sops to /usr/local/bin/:"
sudo mv ./sops /usr/local/bin/ \
    || exit 4

echo "  Making sops executable by all:"
sudo chmod a+x /usr/local/bin/sops \
    || exit 5

echo "SUCCESS Installing sops (\"cube cuddle\") version $SOPS_VERSION."
exit 0
