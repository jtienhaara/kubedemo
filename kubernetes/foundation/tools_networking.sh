#!/bin/sh

echo "Installing networking tools (such as netstat)..."

echo "  Checking sudo access:"
sudo echo "  Granted sudo access." \
    || exit 1


#
# net-tools contains networking troubleshooting tools, such as:
# - netstat
#
sudo apt-get install -y net-tools \
    || exit 1

echo "SUCCESS Installing networking tools (such as netstat)."
exit 0
