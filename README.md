# kubedemo
Small demo to introduce newcomers to Kubernetes and the CNCF.

*** Work in progress 2024-01-29. ***


## Pre-requisites
This demo depends heavily on running Kubernetes using kind
inside a Debian 12 Bookworm VM.

The VM needs:

- The following disks / devices:
  - / Debian 12 Bookworm installed, with at least ~ 10 GB free space
  - /dev/vdd 1 GB (for Rook/Ceph mon 1 on kubedemo-worker)
  - /dev/vde 4 GB (for Rook/Ceph osd 1 on kubedemo-worker)
  - /dev/vdf 1 GB (for Rook/Ceph mon 2 on kubedemo-worker2)
  - /dev/vdg 4 GB (for Rook/Ceph osd 2 on kubedemo-worker2)
  - /dev/vdh 1 GB (for Rook/Ceph mon 3 on kubedemo-worker3)
  - /dev/vdi 4 GB (for Rook/Ceph osd 3 on kubedemo-worker3)
  - /cloud-init Contains the "kubernetes" directory from this git repo

And ideally also:

- 2+ CPUs (1 might suffice)
- 24+ GB RAM (12-16 might suffice)


### Creating the VM using qemu on a Debian 12 Bookworm physical host
If you're already in a Debian (or probably Ubuntu) environment,
and you have a beefy enough physical host to create the qemu VM
(see the pre-requisites above), then you can use the bin/create_vm_qemu.sh
script.

You might want to adjust the configuration first in the file:

    vms/kubedemo.vm

For example, if you want to try running the VM with less RAM or less CPU,
that's the file to edit.

Once you're satisfied with the configuration for the VM, run:

    ./bin/create_vm_qemu.sh vms/kubedemo.vm

This downloads the operating system image if it doesn't exist:

    https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2

And creates the vritual disks and cloud-init script to spin up the VM.

Once the VM is ready to run, you can start it with:

    ./var/lib/vms/kubedemo/bin/start.sh

To watch the boot sequence until it gets to the login prompt, you can
tail the serial output from the VM:

    tail -f ./var/lib/vms/kubedemo/log/serial.log

The serial output can also be useful for troubleshooting the VM, if it goes
wonky for any reason.

To login to the running VM:

    ./var/lib/vms/kubedemo/bin/ssh.sh

To stop it:

    ./var/lib/vms/kubedemo/bin/stop.sh

Or kill the process if it's gone wonky:

    ./var/lib/vms/kubedemo/bin/kill.sh


### Creating the VM on other physical hosts
If you're not already on a Debian (or derived) system, you're
on your own for spinning up an isolated environment in which to test.
There's VirtualBox, vagrant, free-ish versions of commercial virtual
machine software, and so on.

You'll need to create a VM with the pre-requisites listed above,
running a Debian 12 Bookworm image.

With the create_vm.sh script on a Debian 12 Bookworm physical host,
the block devices (/dev/vdd etc) are created using qemu-img,
and the /dev/* device entries are created using the qemu commandline
to start the VM with "-drive ...".

On other, non-qemu virtualization software, you'll have to either
use virtio somehow to create the same /dev/* entries, or else
change the /dev/vd* paths in the Rook/Ceph cluster definition:
kubernetes/foundation/cluster/storage-rook-cluster.yaml


## Kubernetes Demo

Once your Debian 12 Bookworm VM is up and running (see pre-requisites, above),
you can ssh into it to install the Kubernetes demo components.

The whole install process takes around 20 minutes on my laptop at the time
of writing; this will vary widely, depending on RAM and CPU of both the
host machine and of the VM (how many CPUs you've allocated, etc).


### Install foundation layer

SSH into your VM (e.g. `./var/lib/vms/kubedemo/bin/ssh.sh` if you built the VM using create_vm.sh) and run:

    /cloud-init/kubernetes/install.sh

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
- logging: Loki and Promtail
  https://grafana.com/oss/loki/

The layers (foundation, platform, application, operations) are still being built up, work in progress.  Platform layer is the current main focus, then application layer, and eventually operations layer...  One of these days this'll be done.

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
