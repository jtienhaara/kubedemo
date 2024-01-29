#!/bin/sh

#
# Checks to make sure required services are running; if not, shuts down.
#
echo "Checking ssh.service status:"
systemctl status ssh.service \
    || shutdown -h now

echo "SUCCESS Checking services."
exit 0
