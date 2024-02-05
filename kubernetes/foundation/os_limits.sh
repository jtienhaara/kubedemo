#!/bin/sh

echo "Setting operating system limits (# files, fs.inotify limits, etc)..."

echo "  Checking sudo access:"
sudo echo "  Granted sudo access." \
    || exit 1

echo "  Increasing ulimit / NOFILES to 65536 for kind / Docker:"
sudo sed -i.ORIGINAL \
     's|^#DefaultLimitNOFILE=.*$|DefaultLimitNOFILE=65536:524288|' \
     /etc/systemd/system.conf \
    || exit 1
ulimit -n 65536 \
    || exit 1

#
# When we first spin up a Pod that creates a PersistentVolumeClaim backed
# by the Rook / Ceph "kubedemo-block" StorageClass, the PVC and PV are
# created successfully (thanks to our kind cluster being mounted with
# read-write access to the VM's /sys/bus/rbd and /dev/rbd*, without which
# writing a file system to the block store would fail, since the Docker
# container Nodes in kind are otherwise only allowed to read the host's
# /sys and /dev file systems -- see cluster/cluster.yaml extraMounts
# for the worker nodes).
#
# Unfortunately our Vault secrets Pod errors out with:
#
#     failed to create fsnotify watcher: too many open files
#
# So we increase the maximum number of (everything) for fs.inotify here,
# in the hope that this will make all our Pods that mount Persistent Volumes
# happy.
#
# Defaults:
#
#     sudo sysctl fs.inotify
#     fs.inotify.max_queued_events = 16384
#     fs.inotify.max_user_instances = 128
#     fs.inotify.max_user_watches = 187206
#
# We'll try quadrupling these (and hope we don't run out of memory).
#
echo "  Increasing fs.inotify limits for Kubernetes PersistentVolumeClaim mounts:"
sudo sysctl --write fs.inotify.max_queued_events=65536 \
    || exit 1
sudo sysctl --write fs.inotify.max_user_instances=512 \
    || exit 1
sudo sysctl --write fs.inotify.max_user_watches=748824 \
    || exit 1

echo "SUCCESS Setting operating system limits (# files, fs.inotify limits, etc)."
exit 0
