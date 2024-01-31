#!/bin/sh

echo "Installing docker.io..."

echo "  Checking sudo access:"
sudo echo "  Granted sudo access." \
    || exit 1


sudo apt-get install -y docker.io \
    || exit 1

echo "  Finding docker executable:"
DOCKER_EXE=`which docker`
if test -z "$DOCKER_EXE"
then
    echo "ERROR Could not figure out which docker" >&2
    exit 2
fi

echo "  Setting suid bit on $DOCKER_EXE:"
chmod a+s "$DOCKER_EXE" \
    || exit 3

echo "SUCCESS Installing docker.io."
exit 0
