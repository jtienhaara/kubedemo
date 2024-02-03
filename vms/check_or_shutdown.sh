#!/bin/sh

#
# Checks to make sure required services are running; if not, shuts down.
#
echo "Checking ssh.service status:"
sudo systemctl status ssh.service \
    || sudo shutdown -h now

echo "SUCCESS Checking services."
exit 0
