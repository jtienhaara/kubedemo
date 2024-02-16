# kubedemo
Small demo to introduce newcomers to Kubernetes and the CNCF.

*** Work in progress 2024-01-29. ***

## VM
The install scripts for kind, kubectl, and so on are written
for Debian 12 Bookworm.  To run them in an isolated environment,
spin up a Debian VM.

If you're already in a Debian (or probably Ubuntu) environment,
and you have 2 CPUs, 8 GB memory, and 55 GB disk space to spare,
then you can use qemu + kvm to create an isolated environment
in which to install the Kubernetes + CNCF demo software:

    ./src/vm_qemu.sh vms/kubedemo.vm
    ./var/lib/vms/kubedemo/bin/start.sh

To login to the running VM:

    ./var/lib/vms/kubedemo/bin/ssh.sh

To stop it:

    ./var/lib/vms/kubedemo/bin/stop.sh

Or kill the process if it's gone wonky:

    ./var/lib/vms/kubedemo/bin/kill.sh

To troubleshoot bootup issues etc, watch or less the serial output from the VM:

    tail -f ./var/lib/vms/kubedemo/log/serial.log

If you're not already on a Debian (or derived) system, you're
on your own for spinning up an isolated environment in which to test.
There's VirtualBox, vagrant, free-ish versions of commercial virtual
machine software, and so on.

## Kubernetes

### Pre-requisites

Once your VM is spun up and has everything required:

- The following disks / devices:
  - / Debian 12 Bookworm installed, with at least ~ 10 GB free space
  - /dev/vdd 1 GB (for Rook/Ceph)
  - /dev/vde 1 GB (for Rook/Ceph)
  - /dev/vdf 1 GB (for Rook/Ceph)
  - /dev/vdg 1 GB (for Rook/Ceph)
  - /dev/vdh 1 GB (for Rook/Ceph)
  - /dev/vdi 1 GB (for Rook/Ceph)
  - /cloud-init Contains the "kubernetes" directory from this git repo

And ideally also:

- 2+ CPUs (1 might suffice)
- 24+ GB RAM (12-16 might suffice)

### Install foundation

SSH into your VM (e.g. `./var/lib/vms/kubedemo/bin/ssh.sh` if you built the VM using create_vm.sh) and run:

    /cloud-init/kubernetes/install_foundation.sh

This will install pre-requisite software, then step through the various pieces to install the "foundation" layer of kubedemo, which includes:

- storage: Rook/Ceph
  https://rook.io/
- observability: kube-prometheus
  https://github.com/prometheus-operator/kube-prometheus
- certificates: cert-manager and trust-manager
  https://cert-manager.io/
- secrets: HashiCorp Vault
  https://www.hashicorp.com/products/vault
- service mesh: Istio
  https://istio.io/

The foundation layer is still being built up, work in progress.  Platform layer next, then application layer, and eventually operations layer...  One of these days this'll be done.

## Disks warning

Rook / Ceph requires real disks (e.g. /dev/sda, /dev/sdb, etc).  Rook
deliberately disables loopback storage, so you can't just user Docker
volume mounts in kind to provide storage for Rook.

You'll need at least 3 x 1GB "mon" disks, and 3 x 1GB "osd" disks,
for Rook / Ceph to behave well and not inadvertently zero your entire
physical disk.  <-- That's why it's a really good idea to isolate
this Kubernetes demo inside a VM.

The manifests for Rook/Ceph (in particular:
kubernetes/foundation/cluster/storage-rook-cluster.yaml) specify
/dev/vdd ... /dev/vdi as the disks to use for backing storage.
If your backing storage disks are at different devices, and you're
feeling brave, edit the manifests to point to those disks,
instead of /dev/vdd etc.
