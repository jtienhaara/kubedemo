#!/bin/sh

echo "Setting up Debian-compatible OS..."

echo "  Updating package sources:"
sudo apt-get -y update \
    || exit 1

# Instead of running everything through bash in order to time shell scripts,
# install the gnu time command.
# https://packages.debian.org/bookworm/time
echo "  Installing gnu time:"
sudo apt-get install -y time \
    || exit 1

# Not really necessary, Debian(-derived) cloud images come with sshd:
echo "  Installing openssh-server:"
sudo apt-get install -y openssh-server \
    || exit 1

echo "  Fixing permissions in /home/$VM_USER/.ssh:"
sudo chmod -R go-rwx /home/$VM_USER/.ssh/ \
    || exit 1

echo "  Starting SSH server:"
sudo service sshd start \
    || exit 1

echo "SUCCESS Setting up Debian-compatible OS..."
exit 0
