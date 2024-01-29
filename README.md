# kubedemo
Small demo to introduce newcomers to Kubernetes and the CNCF.

*** Work in progress 2024-01-29. ***

## VM
The install scripts for kind, kubectl, and so on are written
for Debian 12 Bookworm.  To run them in an isolated environment,
spin up a Debian VM.

If you're already in a Debian (or probably Ubuntu) environment,
and you have 2 CPUs, 8 GB memory, and 46 GB disk space to spare,
then you can use qemu + kvm to create an isolated environment
in which to install the Kubernetes + CNCF demo software:

    ./src/vm_qemu.sh vms/test0001.vm
    ./var/lib/vms/test0001/bin/start.sh

To login to the running VM:

    ./var/lib/vms/test0001/bin/ssh.sh

To stop it:

    ./var/lib/vms/test0001/bin/stop.sh

Or kill the process if it's gone wonky:

    ./var/lib/vms/test0001/bin/kill.sh

To troubleshoot bootup issues etc, watch or less the serial output from the VM:

    tail -f ./var/lib/vms/test0001/log/serial.log

If you're not already on a Debian (or derived) system, you're
on your own for spinning up an isolated environment in which to test.
There's VirtualBox, vagrant, free-ish versions of commercial virtual
machine software, and so on.

### Disks warning

Rook / Ceph requires real disks (e.g. /dev/sda, /dev/sdb, etc).  Rook
deliberately disables loopback storage, so you can't just user Docker
volume mounts in kind to provide storage for Rook.

You'll need at least 3 x 1GB "mon" disks, and 3 x 1GB "osd" disks,
for Rook / Ceph to behave well and not inadvertently zero your entire
physical disk.  <-- That's why it's a really good idea to isolate
this Kubernetes demo inside a VM.
