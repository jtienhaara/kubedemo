#!/bin/sh

echo "Setting up Debian-compatible OS..."

echo "  Updating package sources:"
apt-get -y update \
    || exit 1

# Not really necessary, Debian(-derived) cloud images come with sshd:
echo "  Installing openssh-server:"
apt-get install -y openssh-server \
    || exit 1

echo "  Fixing permissions in /home/$VM_USER/.ssh:"
chmod -R go-rwx /home/$VM_USER/.ssh/ \
    || exit 1

echo "  Starting SSH server:"
service sshd start \
    || exit 1

echo "SUCCESS Setting up Debian-compatible OS..."
exit 0
