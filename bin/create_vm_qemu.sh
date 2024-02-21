#!/bin/sh

#
# TODO Implement and test for MacOS, Windows:
#
# mac:
#     https://wiki.qemu.org/Hosts/Mac
#     -accel hvf
#
# windows:
#     https://wiki.qemu.org/Hosts/W32#System_emulation
#     --enable-hax
#

if test $# -ne 1 \
        -o -z "$1"
then
    echo "Usage: $0 (vm-file)" >&2
    echo "" >&2
    echo "Creates a qemu virtual machine from the specified settings file." >&2
    echo "" >&2
    echo "Once the VM has been created, it can be started with" >&2
    echo ".../bin/start.sh and stopped with .../bin/stop.sh." >&2
    echo "" >&2
    echo "(vm-file)" >&2
    echo "    A file containing the settings for the VM to create," >&2
    echo "    such as \"test0001.vm\" or \"/home/xyz/test0001.vm\"." >&2
    exit 1
fi

VM_FILE=$1

if test ! -e "$VM_FILE"
then
    echo "ERROR $0 No such vm-file: $VM_FILE" >&2
    exit 2
fi

OS_DISTRIBUTION=`grep '^NAME="' /etc/os-release \
                     2> /dev/null \
                     | sed 's|^NAME="||' \
                     | sed 's|".*$||'`
if test "$OS_DISTRIBUTION" != "Debian GNU/Linux"
then
    echo "ERROR $0 is currently only built to work in Debian GNU/Linux (NAME field in /etc/os-release)." >&2
    exit 3
fi

QEMU_COMMAND=qemu-system-x86_64
VM_ACCELERATION=-enable-kvm

echo "Creating VM from $VM_FILE..."

echo "  Checking sudo access..."
sudo echo "  sudo access granted" \
    || exit 4

echo "  Updating package repo(s)..."
sudo apt-get update -y \
    || exit 5

echo "  Checking required tools..."

echo "    cloud-utils:"
cloud-localds --help \
            2>&1 > /dev/null
if test $? -ne 0
then
    echo "      Installing cloud-utils..."
    sudo apt-get install -y cloud-utils \
        || exit 6
fi

echo "    curl:"
curl --help \
            2>&1 > /dev/null
if test $? -ne 0
then
    echo "      Installing curl..."
    sudo apt-get install -y curl \
        || exit 6
fi

echo "    netstat:"
netstat --interfaces \
        2>&1 > /dev/null
if test $? -ne 0
then
    echo "      Installing net-tools..."
    sudo apt-get install -y net-tools \
        || exit 6
fi

echo "    $QEMU_COMMAND and qemu-img:"
$QEMU_COMMAND --help \
              2>&1 > /dev/null
QEMU_COMMAND_STATUS=$?
qemu-img --help \
         2>&1 > /dev/null
QEMU_IMG_STATUS=$?
if test $QEMU_COMMAND_STATUS -ne 0 \
        -o $QEMU_IMG_STATUS -ne 0
then
    #
    # https://packages.debian.org/bookworm/qemu-system
    # https://packages.debian.org/bookworm/qemu-utils
    # https://packages.debian.org/bookworm/qemu-block-extra
    # https://packages.debian.org/bookworm/qemu-user
    #
    QEMU_PACKAGES="qemu-system qemu-utils qemu-block-extra qemu-user"
    echo "      Installing $QEMU_PACKAGES..."
    sudo apt-get install -y $QEMU_PACKAGES \
        || exit 6
fi

echo "    ssh-keygen:"
which ssh-keygen \
        2>&1 > /dev/null
if test $? -ne 0
then
    echo "      Installing openssh-client..."
    sudo apt-get install -y openssh-client \
        || exit 6
fi


echo "  Retrieving HOST_USER_NAME..."
HOST_USER_NAME=`id --user --name`
echo "  Retrieving HOST_NAME..."
HOST_NAME=`hostname`
echo "  Retrieving HOST_DOMAIN_NAME..."
HOST_DOMAIN_NAME=`dnsdomainname`
if test -z "$HOST_USER_NAME" \
        -o -z "$HOST_NAME"
then
    echo "ERROR Could not determine user name ($HOST_USER_NAME) / host name ($HOST_NAME) (empty domain name is fine: $HOST_DOMAIN_NAME)" >&2
    exit 2
fi

echo "  Checking that kvm group access has taken effect for $HOST_USER_NAME..."
IS_KVM=`id --groups --name | grep kvm`
if test -z "$IS_KVM"
then
    echo "    Enabling kvm virtualization group access for user $HOST_USER_NAME..."
    sudo usermod --append --groups "kvm" "$HOST_USER_NAME" \
        || exit 2

    IS_KVM=`id --groups --name | grep kvm`
    if test -z "$IS_KVM"
    then
        echo "ABORTING You must relogin as user $HOST_USER_NAME to get kvm access.  Or you can 'su - $HOST_USER_NAME' to carry on in a nested environment where your logged in user's groups are up to date." >&2
        exit 2
    fi
fi


# ======================================================================

echo "  Sourcing $VM_FILE:"
. "$VM_FILE" \
    || exit 7
VM_SETTINGS=`cat "$VM_FILE" \
                 | grep '^[ ]*VM_[a-zA-Z_0-9]*=' \
                 | sed 's|^[ ][ ]*||'`
VM_NAME=`basename "$VM_FILE" \
             | sed 's|\..*$||'`

THIS_DIR=$PWD
PARENT_DIR=`dirname "$THIS_DIR"`
VM_PARENT_DIR=`dirname "$VM_FILE" \
                   | sed "s|^\./|$THIS_DIR/|" \
                   | sed "s|^\.\./|$PARENT_DIR/|" \
                   | sed "s|^\\([^/].*\\)\$|$THIS_DIR/\\1|"`
VM_RELATIVE_PARENT_DIR=`echo "$VM_PARENT_DIR" \
                            | sed "s|^$THIS_DIR/||" \
                            | sed "s|^$PARENT_DIR/||"`
# We'll create (if necessary) VM_DIR="$VM_VAR_DIR/${VM_NAME}-files".
# E.g. /x/vms/test0001.vm -> VM_VAR_DIR=/x/var/lib/vms,
# VM_DIR=/x/var/lib/vms/test0001.
if test -z "$VM_VAR_DIR"
then
    VM_ROOT_DIR=`dirname "$VM_PARENT_DIR"`
    if test -z "$VM_ROOT_DIR" \
            -o "$VM_ROOT_DIR" = "/"
    then
        echo "ERROR Could not determine var/lib/vms dir relative to $VM_FILE" >&2
        exit 10
    fi
    VM_VAR_DIR="$VM_ROOT_DIR/var/lib/vms"
fi
VM_DOWNLOADS_DIR="$VM_VAR_DIR/downloads"
VM_DIR="$VM_VAR_DIR/$VM_NAME"
echo "  VM data for \"$VM_NAME\" will be stored in: $VM_DIR"
# Not created yet, until after we've checked settings (below).


# ======================================================================

echo "  Checking to make sure $VM_NAME is not already running ($VM_DIR/pid):"
if test -e "$VM_DIR/pid"
then
    echo "  Checking that $VM_NAME is not already running:"
    VM_PID=`cat "$VM_DIR/pid"`
    VM_PROCESS_NAME=`ps --no-headers -q $VM_PID -o comm= 2> /dev/null`
    VM_MAYBE_QEMU=`echo "$VM_PROCESS_NAME" \
                       | grep '^qemu-'`
    if test ! -z "$VM_MAYBE_QEMU"
    then
        echo "ERROR $VM_NAME pid $VM_PID ($VM_PROCESS_NAME) still running.  Shut it down before re-creating VM." >&2
        exit 12
    fi
fi
echo "    OK $VM_NAME is not running"


# ======================================================================

echo "  Checking VM settings are all present and accounted for..."

IS_ERROR=false

echo "    Checking VM_* acceptable values:"

if test -z "$VM_NAME" \
        -o "$VM_NAME" = "downloads"
then
    echo "ERROR Illegal VM_NAME: '$VM_NAME'" >&2
    IS_ERROR=true
else
    echo "      OK VM_NAME."
fi

if test -z "$VM_NUM_CPUS"
then
    echo "ERROR Illegal VM_NUM_CPUS: '$VM_NUM_CPUS'" >&2
    IS_ERROR=true
else
    echo "      OK VM_NUM_CPUS"
fi

if test -z "$VM_MACHINE"
then
    echo "ERROR Illegal VM_MACHINE: '$VM_MACHINE'" >&2
    IS_ERROR=true
else
    echo "      OK VM_MACHINE"
fi

if test -z "$VM_CPU"
then
    echo "ERROR Illegal VM_CPU: '$VM_CPU'" >&2
    IS_ERROR=true
else
    echo "      OK VM_CPU"
fi

if test -z "$VM_ARCHITECTURE"
then
    echo "ERROR Illegal VM_ARCHITECTURE: '$VM_ARCHITECTURE'" >&2
    IS_ERROR=true
else
    echo "      OK VM_ARCHITECTURE"
fi

if test -z "$VM_MEMORY"
then
    echo "ERROR Illegal VM_MEMORY: '$VM_MEMORY'" >&2
    IS_ERROR=true
else
    echo "      OK VM_MEMORY"
fi

if test -z "$VM_MAC_ADDRESS"
then
    echo "ERROR Illegal VM_MAC_ADDRESS: '$VM_MAC_ADDRESS'" >&2
    IS_ERROR=true
else
    echo "      OK VM_MAC_ADDRESS"
fi

if test -z "$VM_CIDR"
then
    echo "ERROR Illegal VM_CIDR: '$VM_CIDR'" >&2
    IS_ERROR=true
else
    echo "      OK VM_CIDR"
fi

if test -z "$VM_IP_ADDRESS"
then
    echo "ERROR Illegal VM_IP_ADDRESS: '$VM_IP_ADDRESS'" >&2
    IS_ERROR=true
else
    echo "      OK VM_IP_ADDRESS"
fi

# VM_PORTS can be empty.
HOST_PORTS=""
for VM_PORT_PAIR in $VM_PORTS
do
    HOST_PORT=`echo "$VM_PORT_PAIR" \
                   | sed 's|:.*$||'`
    if -test -z "$HOST_PORT" \
             -o "$HOST_PORT" = "$VM_PORT_PAIR"
    then
        echo "ERROR Illegal VM_PORTS port '$HOST_PORT' (in $VM_PORT_PAIR): $VM_PORTS" 2>&1
        IS_ERROR=true
    fi

    NEW_HOST_PORTS="$HOST_PORTS $HOST_PORT"
    HOST_PORTS="$NEW_HOST_PORTS"
done
echo "      OK VM_PORTS"

if test -z "$VM_SSH_PORT"
then
    echo "ERROR Illegal VM_SSH_PORT: '$VM_SSH_PORT'" >&2
    IS_ERROR=true
else
    echo "      OK VM_SSH_PORT"
fi

if test -z "$VM_DISPLAY"
then
    echo "ERROR Illegal VM_DISPLAY: '$VM_DISPLAY'" >&2
    IS_ERROR=true
else
    echo "      OK VM_DISPLAY"
fi

# VM_DISPLAY_OPTIONS can be empty.

if test -z "$VM_DISKS"
then
    echo "ERROR Illegal VM_DISKS: '$VM_DISKS'" >&2
    IS_ERROR=true
else
    echo "      OK VM_DISKS"
fi

if test -z "$VM_USER"
then
    echo "ERROR Illegal VM_USER: '$VM_USER'" >&2
    IS_ERROR=true
else
    echo "      OK VM_USER"
fi

if test -z "$VM_GROUP"
then
    echo "ERROR Illegal VM_GROUP: '$VM_GROUP'" >&2
    IS_ERROR=true
else
    echo "      OK VM_GROUP"
fi

# VM_CLOUD_INIT_RUN can be empty.
# VM_CLOUD_INIT_DATA can be empty.
# VM_POST_BOOT_RUN can be empty.

echo "    Checking VM_DISK_*_* settings:"
for VM_DISK in $VM_DISKS
do
    if test -z "$VM_DISK" \
            -o "$VM_DISK" = "cloud_config"
    then
        echo "ERROR Illegal VM_DISK: '$VM_DISK'" >&2
    fi

    # VM_DISK_x_IMAGE can be empty.
    # VM_DISK_x_SIZE must not be empty.
    VM_DISK_SIZE=`echo "$VM_SETTINGS" \
                      | grep "^VM_DISK_${VM_DISK}_SIZE" \
                      | sed "s|^.*VM_DISK_${VM_DISK}_SIZE=||" \
                      | sed 's|^"||' \
                      | sed 's|".*$||' \
                      | sed "s|^'||" \
                      | sed "s|'.*\$||"`

    if test -z "$VM_DISK_SIZE"
    then
        echo "ERROR Illegal VM_DISK_${VM_DISK}_SIZE: '$VM_DISK_SIZE'" >&2
        IS_ERROR=true
    else
        echo "      OK VM_DISK_${VM_DISK}_SIZE"
    fi
done

#
# Now check to make sure no other servers already have the specified
# ports booked.
#
echo "  Checking availability of ports on the host: $VM_SSH_PORT $HOST_PORTS"
for VM_PORT in $VM_SSH_PORT $HOST_PORTS
do
    HOST_PORT_IN_USE=`netstat --tcp --listening --numeric-hosts --numeric-ports \
                          | awk "\\\$4 ~ /^[^:]*:$VM_PORT\\\$/ { print \\\$0; }" \
                          | sed 's|[ ][ ][ ]*| |g'`
    EXIT_CODE=$?
    if test $EXIT_CODE -ne 0 \
            -o ! -z "$HOST_PORT_IN_USE"
    then
        echo "ERROR Port $VM_PORT cannot be used by VM $VM_NAME: it is already in use." >&2
        exit 8
    fi
    echo "    OK port $VM_PORT is available on this host."
done

VM_CLOUD_INIT_SCRIPTS=""
VM_CLOUD_INIT_RUNCMDS=""
if test ! -z "$VM_CLOUD_INIT_RUN"
then
    echo "    Checking VM_CLOUD_INIT_RUN script(s): $VM_CLOUD_INIT_RUN"
    for VM_CLOUD_INIT_SCRIPT in $VM_CLOUD_INIT_RUN
    do
        VM_CLOUD_INIT_SCRIPT_PATH=""
        VM_CLOUD_INIT_SCRIPT_MOUNTED=""

        if test -e "$VM_PARENT_DIR/$VM_CLOUD_INIT_SCRIPT"
        then
            # Relative path:
            VM_CLOUD_INIT_SCRIPT_PATH="$VM_PARENT_DIR/$VM_CLOUD_INIT_SCRIPT"
            VM_CLOUD_INIT_SCRIPT_MOUNTED="/cloud-init/$VM_RELATIVE_PARENT_DIR/$VM_CLOUD_INIT_SCRIPT"
        else
            # Absolute path?
            if test -e "/$VM_CLOUD_INIT_SCRIPT"
            then
                VM_CLOUD_INIT_SCRIPT_PATH="/$VM_CLOUD_INIT_SCRIPT"
                VM_CLOUD_INIT_SCRIPT_MOUNTED="/cloud-init/$VM_CLOUD_INIT_SCRIPT"
            else
                echo "ERROR Could not find cloud-init script in (/ $VM_PARENT_DIR): $VM_CLOUD_INIT_SCRIPT" >&2
                exit 8
            fi
        fi

        NEW_VM_CLOUD_INIT_SCRIPTS="$VM_CLOUD_INIT_SCRIPTS $VM_CLOUD_INIT_SCRIPT_PATH"
        VM_CLOUD_INIT_SCRIPTS="$NEW_VM_CLOUD_INIT_SCRIPTS"

        NEW_VM_CLOUD_INIT_RUNCMDS="$VM_CLOUD_INIT_RUNCMDS $VM_CLOUD_INIT_SCRIPT_MOUNTED"
        VM_CLOUD_INIT_RUNCMDS="$NEW_VM_CLOUD_INIT_RUNCMDS"

        echo "      OK $VM_CLOUD_INIT_SCRIPT_PATH"
    done
fi

VM_CLOUD_INIT_DATA_FILES=""
if test ! -z "$VM_CLOUD_INIT_DATA"
then
    echo "    Checking VM_CLOUD_INIT_DATA file(s): $VM_CLOUD_INIT_DATA"
    for VM_CLOUD_INIT_DATA_FILE in $VM_CLOUD_INIT_DATA
    do
        VM_CLOUD_INIT_DATA_PATH=""
        if test -e "$VM_PARENT_DIR/$VM_CLOUD_INIT_DATA_FILE" \
                -o -d "$VM_PARENT_DIR/$VM_CLOUD_INIT_DATA_FILE" \
                -o -L "$VM_PARENT_DIR/$VM_CLOUD_INIT_DATA_FILE"
        then
            # Relative path:
            VM_CLOUD_INIT_DATA_PATH="$VM_PARENT_DIR/$VM_CLOUD_INIT_DATA_FILE"
        else
            # Absolute path?
            if test -e "/$VM_CLOUD_INIT_DATA_FILE" \
                    -o -d "/$VM_CLOUD_INIT_DATA_FILE" \
                    -o -L "/$VM_CLOUD_INIT_DATA_FILE"
            then
                VM_CLOUD_INIT_DATA_PATH="/$VM_CLOUD_INIT_DATA_FILE"
            else
                echo "ERROR Could not find cloud-init data file in (/ $VM_PARENT_DIR): $VM_CLOUD_INIT_DATA_FILE" >&2
                exit 8
            fi
        fi

        NEW_VM_CLOUD_INIT_DATA_FILES="$VM_CLOUD_INIT_DATA_FILES $VM_CLOUD_INIT_DATA_PATH"
        VM_CLOUD_INIT_DATA_FILES="$NEW_VM_CLOUD_INIT_DATA_FILES"

        echo "      OK $VM_CLOUD_INIT_DATA_PATH"
    done
fi

VM_POST_BOOT_SCRIPTS=""
if test ! -z "$VM_POST_BOOT_RUN"
then
    echo "    Checking VM_POST_BOOT_RUN script(s): $VM_POST_BOOT_RUN"
    for VM_POST_BOOT_SCRIPT in $VM_POST_BOOT_RUN
    do
        VM_POST_BOOT_SCRIPT_PATH=""
        VM_POST_BOOT_SCRIPT_MOUNTED=""

        if test -e "$VM_PARENT_DIR/$VM_POST_BOOT_SCRIPT"
        then
            # Relative path:
            VM_POST_BOOT_SCRIPT_PATH="$VM_PARENT_DIR/$VM_POST_BOOT_SCRIPT"
            VM_POST_BOOT_SCRIPT_MOUNTED="/cloud-init/$VM_RELATIVE_PARENT_DIR/$VM_POST_BOOT_SCRIPT"
        else
            # Absolute path?
            if test -e "/$VM_POST_BOOT_SCRIPT"
            then
                VM_POST_BOOT_SCRIPT_PATH="/$VM_POST_BOOT_SCRIPT"
                VM_POST_BOOT_SCRIPT_MOUNTED="/cloud-init/$VM_POST_BOOT_SCRIPT"
            else
                echo "ERROR Could not find cloud-init script in (/ $VM_PARENT_DIR): $VM_POST_BOOT_SCRIPT" >&2
                exit 8
            fi
        fi

        NEW_VM_POST_BOOT_SCRIPTS="$VM_POST_BOOT_SCRIPTS $VM_POST_BOOT_SCRIPT_MOUNTED"
        VM_POST_BOOT_SCRIPTS="$NEW_VM_POST_BOOT_SCRIPTS"

        echo "      OK $VM_POST_BOOT_SCRIPT_PATH"
    done
fi

if test -z "$HOST_EMAIL_ADDRESS"
then
    echo "  Setting up HOST_EMAIL_ADDRESS:"
    if test -z "$HOST_DOMAIN_NAME"
    then
        HOST_EMAIL_ADDRESS="$HOST_USER_NAME@$HOST_NAME"
    else
        HOST_EMAIL_ADDRESS="$HOST_USER_NAME@${HOST_NAME}.${HOST_DOMAIN_NAME}"
    fi
    echo "    OK $HOST_EMAIL_ADDRESS"
fi

if test -z "$VM_FQDN"
then
    echo "  Setting up VM_FQDN:"
    if test -z "$HOST_DOMAIN_NAME"
    then
        VM_FQDN="$VM_NAME"
    else
        VM_FQDN="${VM_NAME}.${HOST_DOMAIN_NAME}"
    fi
    echo "    OK $VM_FQDN"
fi

#
# Exit if any of the settings produced error(s).
#
if test "$IS_ERROR" != "false"
then
    exit 9
fi


# ======================================================================

echo "  Checking / creating directories for VM data and downloads..."

#
# Make sure VM_VAR_DIR exists (e.g. x/y/z/var/lib/vms, or /var/lib/vms).
#
mkdir -p "$VM_VAR_DIR" 2>&1 > /dev/null \
    || ( sudo mkdir -p "$VM_VAR_DIR" \
             && sudo chmod a+rwx "$VM_VAR_DIR" ) \
    || exit 11
echo "    OK $VM_VAR_DIR"

#
# Make sure VM_VAR_DIR/downloads exists.
#
mkdir -p "$VM_DOWNLOADS_DIR" \
      || exit 11

#
# Make sure VM_DIR exists, create it if necessary, and blow away its contents.
#
if test -d "$VM_DIR"
then
    rm -rf $VM_DIR/* \
        || exit 11
fi
mkdir -p "$VM_DIR" \
    || exit 11
chmod go-rwx "$VM_DIR" \
    || exit 11
echo "    OK $VM_DIR"

mkdir -p "$VM_DIR/bin" \
    || exit 11
echo "    OK $VM_DIR/bin"

mkdir -p "$VM_DIR/cloud-config" \
    || exit 11
echo "    OK $VM_DIR/cloud-config"

mkdir -p "$VM_DIR/disks" \
    || exit 11
echo "    OK $VM_DIR/disks"

mkdir -p "$VM_DIR/log" \
    || exit 11
echo "    OK $VM_DIR/log"


# ======================================================================

echo "  Checking / creating SSH key pair for $HOST_EMAIL_ADDRESS, so you can ssh into $VM_NAME..."
if test ! -e "$VM_DIR/ssh.key.pub"
then
    echo "    Generating SSH key pair for $HOST_EMAIL_ADDRESS:"
    ssh-keygen \
        -t ed25519 \
        -C "$HOST_EMAIL_ADDRESS" \
        -P "" \
        -f "$VM_DIR/ssh.key" \
        || exit 13
fi
chmod u-wx,go-rwx "$VM_DIR/ssh.key" \
    || exit 13
SSH_PUBLIC_KEY=`cat "$VM_DIR/ssh.key.pub"`
if test -z "$SSH_PUBLIC_KEY"
then
    echo "ERROR Failed generating public/private SSH keys for $VM_NAME" >&2
    exit 13
fi

echo "    OK SSH key pair for $HOST_EMAIL_ADDRESS"


# ======================================================================

echo "  Populating cloud-config dir for cloud-init..."
rm -rf "$VM_DIR/cloud-config/" \
    && mkdir -p "$VM_DIR/cloud-config/" \
        || exit 14

echo "    Creating $VM_DIR/cloud-config/user-data.yaml..."
cat > "$VM_DIR/cloud-config/user-data.yaml" << END_OF_CLOUD_CONFIG
#cloud-config
users:
  - default
  - name: $VM_USER
    plain_text_passwd: REPLACED_DURING_CLOUD_INIT
    sudo: ALL=(ALL) NOPASSWD:ALL
    primary_group: $VM_GROUP
    groups: users
    shell: /bin/bash
    ssh_authorized_keys:
      - $SSH_PUBLIC_KEY
preserve_hostname: false
hostname: $VM_NAME
fqdn: $VM_FQDN
END_OF_CLOUD_CONFIG
EXIT_CODE=$?

if test ! -f "$VM_DIR/cloud-config/user-data.yaml" \
        -o $EXIT_CODE -ne 0
then
    echo "ERROR Could not create cloud-init file: $VM_DIR/cloud-config/user-data.yaml" >&2
    exit 15
fi

cat >> "$VM_DIR/cloud-config/user-data.yaml" << END_OF_CLOUD_CONFIG
runcmd:
  - echo "======================================================================"
  - echo "VM $VM_NAME environment setup:"
  - echo "export VM_NAME=\"$VM_NAME\"" >> /root/.bashrc
  - echo "export VM_USER=\"$VM_USER\"" >> /root/.bashrc
  - echo "export VM_GROUP=\"$VM_GROUP\"" >> /root/.bashrc
  - echo "export VM_PORTS=\"$VM_PORTS\"" >> /root/.bashrc
  - echo "export VM_DISKS=\"$VM_DISKS\"" >> /root/.bashrc
  - . /root/.bashrc
  - while test ! -d /home/$VM_USER; do echo "Waiting 5 seconds for user $VM_USER home directory to be created..."; sleep 5; done
  # 128 bit random password:
  - head --bytes 16 /dev/urandom | base64 --wrap 0 | sed 's|^\\(.*\\)\$|$VM_USER:\\1|' | chpasswd || ( echo "***** FAILED to chpasswd $VM_USER *****" >&2 ; shutdown -h now )
  - echo "export VM_NAME=\"$VM_NAME\"" >> /home/$VM_USER/.bashrc
  - echo "export VM_USER=\"$VM_USER\"" >> /home/$VM_USER/.bashrc
  - echo "export VM_GROUP=\"$VM_GROUP\"" >> /home/$VM_USER/.bashrc
  - echo "export VM_PORTS=\"$VM_PORTS\"" >> /home/$VM_USER/.bashrc
  - echo "export VM_DISKS=\"$VM_DISKS\"" >> /home/$VM_USER/.bashrc
  - chown $VM_USER:$VM_GROUP /home/$VM_USER/.bashrc || ( echo "***** FAILED to chown $VM_USER:$VM_GROUP /home/$VM_USER/.bashrc *****" >&2 ; shutdown -h now )
  - echo "Mounting /cloud-init:"
  - mkdir -p /cloud-init
  # Always mount /cloud-init at bootup:
  - echo "/dev/vdc /cloud-init ext4 rw,relatime 0 0" >> /etc/fstab || ( echo "***** FAILED to modify /etc/fstab with /cloud-init/ mount options *****" >&2 ; shutdown -h now )
  - mount /cloud-init || ( echo "***** FAILED to mount /cloud-init/ *****" >&2 ; shutdown -h now )
  - chown -R $VM_USER:$VM_GROUP /cloud-init/ || ( echo "***** FAILED to chown $VM_USER /cloud-init/ *****" >&2 ; shutdown -h now )
  - echo "SUCCESS Mounting /cloud-init."
  - echo "----------------------------------------------------------------------"
END_OF_CLOUD_CONFIG
EXIT_CODE=$?

if test $EXIT_CODE -ne 0
then
    echo "ERROR Could not add initial runcmds to cloud-init file: $VM_DIR/cloud-config/user-data.yaml" >&2
    exit 15
fi

for VM_CLOUD_INIT_RUNCMD in $VM_CLOUD_INIT_RUNCMDS
do
    echo "  - echo \"======================================================================\"" \
         >> "$VM_DIR/cloud-config/user-data.yaml" \
        || exit 15
    echo "  - echo \"$VM_CLOUD_INIT_RUNCMD:\"" \
         >> "$VM_DIR/cloud-config/user-data.yaml" \
        || exit 15
    echo "  - $VM_CLOUD_INIT_RUNCMD || ( echo \"***** FAILED to run $VM_CLOUD_INIT_RUNCMD *****\" >&2 ; shutdown -h now )" \
         >> "$VM_DIR/cloud-config/user-data.yaml" \
        || exit 15
    echo "  - echo \"----------------------------------------------------------------------\"" \
         >> "$VM_DIR/cloud-config/user-data.yaml" \
        || exit 15

    echo "      OK adding runcmd $VM_CLOUD_INIT_SCRIPT"
done

echo "    OK populating cloud-config directory"


# ======================================================================

echo "  Writing VM disks ($VM_DIR/disks)..."

echo "    Creating cloud_config disk from cloud-init user-data.yaml:"
cloud-localds \
    "$VM_DIR/disks/disk_cloud_config.img" \
    "$VM_DIR/cloud-config/user-data.yaml" \
    || exit 16
echo "      OK $VM_DIR/disks/disk_cloud_config.img"

echo "    Removing existing disk(s) (if any)..."
for VM_DISK in $VM_DISKS
do
    if test ! -e "$VM_DIR/disks/disk_${VM_DISK}.qcow2"
    then
        continue
    fi

    rm -f "$VM_DIR/disks/disk_${VM_DISK}.qcow2" \
        || exit 16
    echo "      OK $VM_DIR/disks/disk_${VM_DISK}.qcow2"
done

echo "    Downloading disk image(s) (if any)..."
for VM_DISK in $VM_DISKS
do
    VM_IMAGE_URL=`echo "$VM_SETTINGS" \
                      | grep "^VM_DISK_${VM_DISK}_IMAGE" \
                      | sed "s|^.*VM_DISK_${VM_DISK}_IMAGE=||" \
                      | sed 's|^"||' \
                      | sed 's|".*$||' \
                      | sed "s|^'||" \
                      | sed "s|'.*\$||"`
    if test -z "$VM_IMAGE_URL"
    then
        # We'll create empty disks later.
        continue
    fi

    VM_DISK_SIZE=`echo "$VM_SETTINGS" \
                      | grep "^VM_DISK_${VM_DISK}_SIZE" \
                      | sed "s|^.*VM_DISK_${VM_DISK}_SIZE=||" \
                      | sed 's|^"||' \
                      | sed 's|".*$||' \
                      | sed "s|^'||" \
                      | sed "s|'.*\$||"`

    VM_IMAGE_FILENAME=`basename "$VM_IMAGE_URL"`
    VM_DOWNLOADED_IMAGE="$VM_DOWNLOADS_DIR/$VM_IMAGE_FILENAME"
    if test  ! -e "$VM_DOWNLOADED_IMAGE"
    then
        echo "      Downloading $VM_IMAGE_URL to $VM_DOWNLOADED_IMAGE:"
        curl --location "$VM_IMAGE_URL" --output "$VM_DOWNLOADED_IMAGE" \
            || exit 16
    fi

    echo "      Copying $VM_DOWNLOADED_IMAGE to $VM_DIR/disks/disk_${VM_DISK}.qcow2:"
    cp -f "$VM_DOWNLOADED_IMAGE" "$VM_DIR/disks/disk_${VM_DISK}.qcow2" \
        || exit 16

    echo "      Resizing disk_${VM_DISK}.qcow2: $VM_DISK_SIZE"
    qemu-img resize "$VM_DIR/disks/disk_${VM_DISK}.qcow2" "$VM_DISK_SIZE" \
        || exit 16

    echo "      OK disks/disk_${VM_DISK}.qcow2 ($VM_DISK_SIZE)"
done
echo "    OK downloading disk image(s) (if any)..."

echo "    Creating empty disk(s) (if any)..."
for VM_DISK in $VM_DISKS
do
    VM_IMAGE_URL=`echo "$VM_SETTINGS" \
                      | grep "^VM_DISK_${VM_DISK}_IMAGE" \
                      | sed "s|^.*VM_DISK_${VM_DISK}_IMAGE=||" \
                      | sed 's|^"||' \
                      | sed 's|".*$||' \
                      | sed "s|^'||" \
                      | sed "s|'.*\$||"`
    if test ! -z "$VM_IMAGE_URL"
    then
        # We already downloaded disk images earlier.
        continue
    fi

    VM_DISK_SIZE=`echo "$VM_SETTINGS" \
                      | grep "^VM_DISK_${VM_DISK}_SIZE" \
                      | sed "s|^.*VM_DISK_${VM_DISK}_SIZE=||" \
                      | sed 's|^"||' \
                      | sed 's|".*$||' \
                      | sed "s|^'||" \
                      | sed "s|'.*\$||"`

    echo "      Creating disk_${VM_DISK}.qcow2: $VM_DISK_SIZE"
    qemu-img create -f qcow2 \
             "$VM_DIR/disks/disk_${VM_DISK}.qcow2" "$VM_DISK_SIZE" \
        || exit 16

    echo "      OK disks/disk_${VM_DISK}.qcow2 ($VM_DISK_SIZE)"
done

echo "      OK creating empty disk(s)."

echo "    Creating cloud-init disk:"
VM_CLOUD_INIT_DIR="$VM_DIR/disks/cloud-init"
VM_CLOUD_INIT_DISK="$VM_DIR/disks/cloud-init.img"
# Enough room for metadata plus wiggle room once it's mounted in the VM;
# we'll expand the # of bytes for scripts, data files:
VM_CLOUD_INIT_BYTES=4194304

for VM_CLOUD_INIT_FILE in $VM_CLOUD_INIT_SCRIPTS $VM_CLOUD_INIT_DATA_FILES
do
    echo "      Cloud-init file size ($VM_CLOUD_INIT_FILE):"
    VM_CLOUD_INIT_FILE_BYTES=`sudo du -s -c -b $VM_CLOUD_INIT_FILE \
                                  | tail -1 \
                                  | awk '{ printf $1; }'`
    EXIT_CODE=$?
    if test -z "$VM_CLOUD_INIT_FILE_BYTES" \
            -o $EXIT_CODE -ne 0
    then
        echo "ERROR Could not determine bytes size of cloud-init file ($VM_CLOUD_INIT_FILE): $VM_CLOUD_INIT_FILE_BYTES" >&2
        exit 16
    fi

    NEW_VM_CLOUD_INIT_BYTES=`expr $VM_CLOUD_INIT_BYTES + $VM_CLOUD_INIT_FILE_BYTES`
    VM_CLOUD_INIT_BYTES="$NEW_VM_CLOUD_INIT_BYTES"
done

#
# Now double the number of bytes for the disk, since metadata since
# to take up a lot of space:
#
NEW_VM_CLOUD_INIT_BYTES=`expr $VM_CLOUD_INIT_BYTES \* 2`
VM_CLOUD_INIT_BYTES=$NEW_VM_CLOUD_INIT_BYTES

echo "      Creating cloud-init disk image ($VM_CLOUD_INIT_BYTES bytes):"
dd if=/dev/zero of=$VM_CLOUD_INIT_DISK bs=1 \
   count=$VM_CLOUD_INIT_BYTES \
    || exit 16
if test ! -s "$VM_CLOUD_INIT_DISK"
then
    echo "ERROR $VM_CLOUD_INIT_DISK is 0 bytes after dd!" >&2
    exit 16
fi
echo "        OK creating cloud-init disk image."

echo "      Making ext4 filesystem on cloud-init disk image:"
# -F to force making a file system on non-block device:
sudo mkfs.ext4 -L "cloud-init" -F "$VM_CLOUD_INIT_DISK" \
    || exit 16
echo "        OK making ext4 filesystem on cloud-init disk image."

echo "      Copying cloud-init files to cloud-init disk image:"
mkdir -p "$VM_CLOUD_INIT_DIR" \
    || exit 16

sudo mount -t ext4 -o loop "$VM_CLOUD_INIT_DISK" "$VM_CLOUD_INIT_DIR" \
    || exit 16

sudo chown -R "$HOST_USER_NAME" "$VM_CLOUD_INIT_DIR"
EXIT_CODE=$?
if test $EXIT_CODE -ne 0
then
    sudo umount "$VM_CLOUD_INIT_DIR"
    exit 16
fi

for VM_CLOUD_INIT_FILE in $VM_CLOUD_INIT_RUN $VM_CLOUD_INIT_DATA
do
    VM_CLOUD_INIT_FILE_PATH=""
    VM_CLOUD_INIT_FILE_MOUNTED=""

    if test -e "$VM_PARENT_DIR/$VM_CLOUD_INIT_FILE"
    then
        # Relative path:
        VM_CLOUD_INIT_FILE_PATH="$VM_PARENT_DIR/$VM_CLOUD_INIT_FILE"
        VM_CLOUD_INIT_FILE_MOUNTED="$VM_CLOUD_INIT_DIR/$VM_RELATIVE_PARENT_DIR/$VM_CLOUD_INIT_FILE"
    else
        # Absolute path?
        if test -e "/$VM_CLOUD_INIT_FILE"
        then
            VM_CLOUD_INIT_FILE_PATH="/$VM_CLOUD_INIT_FILE"
            VM_CLOUD_INIT_FILE_MOUNTED="$VM_CLOUD_INIT_DIR/$VM_CLOUD_INIT_FILE"
        else
            echo "ERROR Could not find cloud-init file in (/ $VM_PARENT_DIR): $VM_CLOUD_INIT_FILE" >&2
            sudo umount "$VM_CLOUD_INIT_DIR"
            exit 16
        fi
    fi

    VM_CLOUD_INIT_DIR_MOUNTED=`dirname "$VM_CLOUD_INIT_FILE_MOUNTED"`

    echo "        Copying $VM_CLOUD_INIT_FILE_PATH to $VM_CLOUD_INIT_DIR_MOUNTED:"
    mkdir -p "$VM_CLOUD_INIT_DIR_MOUNTED"
    EXIT_CODE=$?
    if test $EXIT_CODE -ne 0
    then
        sudo umount "$VM_CLOUD_INIT_DIR"
        exit 16
    fi

    cp -r "$VM_CLOUD_INIT_FILE_PATH" "$VM_CLOUD_INIT_FILE_MOUNTED"
    EXIT_CODE=$?
    if test $EXIT_CODE -ne 0
    then
        sudo umount "$VM_CLOUD_INIT_DIR"
        exit 16
    fi

    echo "          OK copying $VM_CLOUD_INIT_FILE_PATH."
done

sudo umount "$VM_CLOUD_INIT_DIR" \
    || exit 16

echo "      OK creating cloud-init data disk."

# ======================================================================

echo "  Creating ssh script for VM $VM_NAME:"
echo "#!/bin/sh" \
     > "$VM_DIR/bin/ssh.sh" \
    || exit 17
echo "" \
     >> "$VM_DIR/bin/ssh.sh" \
    || exit 17
echo "SSH_START_TIME=\`date '+%s'\`" \
     >> "$VM_DIR/bin/ssh.sh" \
    || exit 17
echo "ssh -p $VM_SSH_PORT -i $VM_DIR/ssh.key -o StrictHostKeyChecking=accept-new $VM_USER@localhost \$@" \
     >> "$VM_DIR/bin/ssh.sh" \
    || exit 17
echo "EXIT_CODE=\$?" \
     >> "$VM_DIR/bin/ssh.sh" \
    || exit 17
echo "SSH_END_TIME=\`date '+%s'\`" \
     >> "$VM_DIR/bin/ssh.sh" \
    || exit 17
echo "SSH_DIFF_TIME=\`expr \$SSH_END_TIME - \$SSH_START_TIME\`" \
     >> "$VM_DIR/bin/ssh.sh" \
    || exit 17
echo "if test \$EXIT_CODE -ne 0 \\" \
     >> "$VM_DIR/bin/ssh.sh" \
    || exit 17
echo "    -a \$SSH_DIFF_TIME -le 1" \
     >> "$VM_DIR/bin/ssh.sh" \
    || exit 17
echo "then" \
     >> "$VM_DIR/bin/ssh.sh" \
    || exit 17
echo "    # Remove any previous keys:" \
     >> "$VM_DIR/bin/ssh.sh" \
    || exit 17
echo "    ssh-keygen -f \"\$HOME/.ssh/known_hosts\" -R \"[localhost]:$VM_SSH_PORT\"" \
     >> "$VM_DIR/bin/ssh.sh" \
    || exit 17
echo "" \
     >> "$VM_DIR/bin/ssh.sh" \
    || exit 17
echo "    # Now try again:" \
     >> "$VM_DIR/bin/ssh.sh" \
    || exit 17
echo "    ssh -p $VM_SSH_PORT -i $VM_DIR/ssh.key -o StrictHostKeyChecking=accept-new $VM_USER@localhost \$@" \
     >> "$VM_DIR/bin/ssh.sh" \
    || exit 17
echo "    EXIT_CODE=\$?" \
     >> "$VM_DIR/bin/ssh.sh" \
    || exit 17
echo "fi" \
     >> "$VM_DIR/bin/ssh.sh" \
    || exit 17
echo "" \
     >> "$VM_DIR/bin/ssh.sh" \
    || exit 17
echo "exit \$EXIT_CODE" \
     >> "$VM_DIR/bin/ssh.sh" \
    || exit 17
chmod u+x,go-rwx "$VM_DIR/bin/ssh.sh" \
    || exit 17
echo "    OK $VM_DIR/bin/ssh.sh"

echo "  Copying $VM_FILE to $VM_DIR/settings.vm:"
cp -f "$VM_FILE" "$VM_DIR/settings.vm" \
    || exit 17
echo "    OK $VM_DIR/settings.vm"

echo "  Creating $VM_DIR/bin/post_boot.sh, called by start.sh..."
echo "#!/bin/sh" \
     > "$VM_DIR/bin/post_boot.sh" \
    || exit 17
echo "" \
     >> "$VM_DIR/bin/post_boot.sh" \
    || exit 17
echo "BIN_DIR=\`dirname \$0\`" \
     >> "$VM_DIR/bin/post_boot.sh" \
    || exit 17
echo "RUN_DIR=\`dirname \$BIN_DIR\`" \
     >> "$VM_DIR/bin/post_boot.sh" \
    || exit 17
echo "echo \"Executing post-boot scripts...\"" \
     >> "$VM_DIR/bin/post_boot.sh" \
    || exit 17
for VM_POST_BOOT_SCRIPT in $VM_POST_BOOT_SCRIPTS
do
    echo "echo \"  Executing \"$VM_POST_BOOT_SCRIPT\":\"" \
         >> "$VM_DIR/bin/post_boot.sh" \
        || exit 17
    echo "\$RUN_DIR/bin/ssh.sh $VM_POST_BOOT_SCRIPT || exit 1" \
         >> "$VM_DIR/bin/post_boot.sh" \
        || exit 17
done
echo "echo \"SUCCESSExecuting post-boot scripts.\"" \
     >> "$VM_DIR/bin/post_boot.sh" \
    || exit 17
echo "exit 0" \
     >> "$VM_DIR/bin/post_boot.sh" \
    || exit 17
chmod u+x,go-rwx "$VM_DIR/bin/post_boot.sh" \
    || exit 17
echo "    OK $VM_DIR/bin/post_boot.sh"


echo "  Creating $VM_DIR/bin/start.sh, $VM_DIR/bin/stop.sh and $VM_DIR/bin/kill.sh..."

# bin/start.sh
echo "#!/bin/sh" \
     > "$VM_DIR/bin/start.sh" \
    || exit 17
echo "" \
     >> "$VM_DIR/bin/start.sh" \
    || exit 17
echo "BIN_DIR=\`dirname \$0\`" \
     >> "$VM_DIR/bin/start.sh" \
    || exit 17
echo "RUN_DIR=\`dirname \$BIN_DIR\`" \
     >> "$VM_DIR/bin/start.sh" \
    || exit 17
echo "rm -f \$RUN_DIR/log/serial.log || exit 1" \
     >> "$VM_DIR/bin/start.sh" \
    || exit 17
echo "" \
     >> "$VM_DIR/bin/start.sh" \
    || exit 17
echo "VM_PID=\`cat \"\$RUN_DIR/pid\" 2> /dev/null\`" \
     >> "$VM_DIR/bin/start.sh" \
    || exit 17
echo "if test ! -z \"\$VM_PID\"" \
     >> "$VM_DIR/bin/start.sh" \
    || exit 17
echo "then" \
     >> "$VM_DIR/bin/start.sh" \
    || exit 17
echo "    VM_PROCESS_NAME=\`ps --no-headers -q \$VM_PID -o comm= 2> /dev/null\`" \
     >> "$VM_DIR/bin/start.sh" \
    || exit 17
echo "    VM_MAYBE_QEMU=\`echo \"\$VM_PROCESS_NAME\" \\" \
     >> "$VM_DIR/bin/start.sh" \
    || exit 17
echo "                       | grep '^qemu-'\`" \
     >> "$VM_DIR/bin/start.sh" \
    || exit 17
echo "    if test ! -z \"\$VM_MAYBE_QEMU\"" \
     >> "$VM_DIR/bin/start.sh" \
    || exit 17
echo "    then" \
     >> "$VM_DIR/bin/start.sh" \
    || exit 17
echo "        echo \"ERROR $VM_NAME pid \$VM_PID (\$VM_PROCESS_NAME) still running.  Shut it down before re-running VM.\" >&2" \
     >> "$VM_DIR/bin/start.sh" \
    || exit 17
echo "        exit 2" \
     >> "$VM_DIR/bin/start.sh" \
    || exit 17
echo "    fi" \
     >> "$VM_DIR/bin/start.sh" \
    || exit 17
echo "fi" \
     >> "$VM_DIR/bin/start.sh" \
    || exit 17
echo "" \
     >> "$VM_DIR/bin/start.sh" \
    || exit 17
echo "echo \"Starting VM $VM_NAME with $QEMU_COMMAND...\"" \
     >> "$VM_DIR/bin/start.sh" \
    || exit 17
echo "$QEMU_COMMAND \\" \
     >> "$VM_DIR/bin/start.sh" \
    || exit 17
echo "    -name \"$VM_NAME\" \\" \
     >> "$VM_DIR/bin/start.sh" \
    || exit 17
echo "    -serial file:\$RUN_DIR/log/serial.log \\" \
     >> "$VM_DIR/bin/start.sh" \
    || exit 17
echo "    -display \"$VM_DISPLAY\" \\" \
     >> "$VM_DIR/bin/start.sh" \
    || exit 17
echo "    $VM_DISPLAY_OPTIONS \\" \
     >> "$VM_DIR/bin/start.sh" \
    || exit 17
echo "    -machine $VM_MACHINE \\" \
     >> "$VM_DIR/bin/start.sh" \
    || exit 17
echo "    -m $VM_MEMORY \\" \
     >> "$VM_DIR/bin/start.sh" \
    || exit 17
echo "    -smp cpus=\"$VM_NUM_CPUS\" \\" \
     >> "$VM_DIR/bin/start.sh" \
    || exit 17
echo "    -cpu $VM_CPU \\" \
     >> "$VM_DIR/bin/start.sh" \
    || exit 17
echo "    $VM_ACCELERATION \\" \
     >> "$VM_DIR/bin/start.sh" \
    || exit 17
echo -n "    -netdev user,id=net0" \
     >> "$VM_DIR/bin/start.sh" \
    || exit 17
echo -n ",hostfwd=tcp::$VM_SSH_PORT-:22" \
     >> "$VM_DIR/bin/start.sh" \
    || exit 17
for VM_PORT_PAIR in $VM_PORTS
do
    HOST_PORT=`echo "$VM_PORT_PAIR" \
                   | sed 's|:.*$||'`
    VM_PORT=`echo "$VM_PORT_PAIR" \
                 | sed 's|^.*:||'`
    echo -n ",hostfwd=tcp::$HOST_PORT-:$VM_PORT" \
         >> "$VM_DIR/bin/start.sh" \
        || exit 17
done
echo ",net=$VM_CIDR,dhcpstart=$VM_IP_ADDRESS \\" \
     >> "$VM_DIR/bin/start.sh" \
    || exit 17
echo "    -device virtio-net-pci,netdev=net0,mac=$VM_MAC_ADDRESS \\" \
     >> "$VM_DIR/bin/start.sh" \
    || exit 17

IS_FIRST_DISK=true
for VM_DISK in $VM_DISKS
do
    echo "    -drive id=$VM_DISK,file=\$RUN_DIR/disks/disk_${VM_DISK}.qcow2,if=virtio,format=qcow2,cache=none \\" \
         >> "$VM_DIR/bin/start.sh" \
        || exit 17
    if test "$IS_FIRST_DISK" = "true"
    then
        # /dev/vdb: cloud-init (user-data.yaml) disk is second:
        echo "    -drive id=cloud_config,file=\$RUN_DIR/disks/disk_cloud_config.img,if=virtio,format=raw,cache=none \\" \
             >> "$VM_DIR/bin/start.sh" \
            || exit 17

        # /dev/vdc: Mount all the scripts and data used by the
        #           cloud-init user-data.yaml:
        echo "    -drive id=cloud-init,file=\$RUN_DIR/disks/cloud-init.img,if=virtio,format=raw,cache=none \\" \
             >> "$VM_DIR/bin/start.sh" \
            || exit 17

        IS_FIRST_DISK=false
    fi
done

echo "    -daemonize \\" \
     >> "$VM_DIR/bin/start.sh" \
    || exit 17
echo "    -pidfile \$RUN_DIR/pid \\" \
     >> "$VM_DIR/bin/start.sh" \
    || exit 17
echo "    || exit 1" \
     >> "$VM_DIR/bin/start.sh" \
    || exit 17
echo "" \
     >> "$VM_DIR/bin/start.sh" \
    || exit 17
echo "echo \"You can follow bootup with:\"" \
     >> "$VM_DIR/bin/start.sh" \
    || exit 17
echo "" \
     >> "$VM_DIR/bin/start.sh" \
    || exit 17
echo "echo \"    tail -f \$RUN_DIR/log/serial.log\"" \
     >> "$VM_DIR/bin/start.sh" \
    || exit 17
echo "" \
     >> "$VM_DIR/bin/start.sh" \
    || exit 17
echo "echo \"You can run post-boot scripts with:\"" \
     >> "$VM_DIR/bin/start.sh" \
    || exit 17
echo "" \
     >> "$VM_DIR/bin/start.sh" \
    || exit 17
echo "echo \"    $VM_DIR/bin/post_boot.sh\"" \
     >> "$VM_DIR/bin/start.sh" \
    || exit 17
echo "" \
     >> "$VM_DIR/bin/start.sh" \
    || exit 17
echo "echo \"SUCCESS Starting VM $VM_NAME with $QEMU_COMMAND.\"" \
     >> "$VM_DIR/bin/start.sh" \
    || exit 17
echo "exit 0" \
     >> "$VM_DIR/bin/start.sh" \
    || exit 17
chmod u+x,go-rwx "$VM_DIR/bin/start.sh" \
    || exit 17
echo "    OK $VM_DIR/bin/start.sh"

# bin/stop.sh
echo "#!/bin/sh" \
     > "$VM_DIR/bin/stop.sh" \
    || exit 17
echo "" \
     >> "$VM_DIR/bin/stop.sh" \
    || exit 17
echo "BIN_DIR=\`dirname \$0\`" \
     >> "$VM_DIR/bin/stop.sh" \
    || exit 17
echo "RUN_DIR=\`dirname \$BIN_DIR\`" \
     >> "$VM_DIR/bin/stop.sh" \
    || exit 17
echo "echo \"Stopping VM $VM_NAME...\"" \
     >> "$VM_DIR/bin/stop.sh" \
    || exit 17
echo "\$RUN_DIR/bin/ssh.sh sudo shutdown -h now || exit 1" \
     >> "$VM_DIR/bin/stop.sh" \
    || exit 17
echo "" \
     >> "$VM_DIR/bin/stop.sh" \
    || exit 17
echo "echo \"SUCCESS Stopping VM $VM_NAME.\"" \
     >> "$VM_DIR/bin/stop.sh" \
    || exit 17
echo "exit 0" \
     >> "$VM_DIR/bin/stop.sh" \
    || exit 17
chmod u+x,go-rwx "$VM_DIR/bin/stop.sh" \
    || exit 17
echo "    OK $VM_DIR/bin/stop.sh"

# bin/kill.sh
echo "#!/bin/sh" \
     > "$VM_DIR/bin/kill.sh" \
    || exit 17
echo "" \
     >> "$VM_DIR/bin/kill.sh" \
    || exit 17
echo "BIN_DIR=\`dirname \$0\`" \
     >> "$VM_DIR/bin/kill.sh" \
    || exit 17
echo "RUN_DIR=\`dirname \$BIN_DIR\`" \
     >> "$VM_DIR/bin/kill.sh" \
    || exit 17
echo "VM_PID=\`cat \"\$RUN_DIR/pid\" 2> /dev/null\`" \
     >> "$VM_DIR/bin/kill.sh" \
    || exit 17
echo "if test -z \"\$VM_PID\"" \
     >> "$VM_DIR/bin/kill.sh" \
    || exit 17
echo "then" \
     >> "$VM_DIR/bin/kill.sh" \
    || exit 17
echo "    echo \"ERROR No pid file in \$RUN_DIR\" >&2" \
     >> "$VM_DIR/bin/kill.sh" \
    || exit 17
echo "    exit 1" \
     >> "$VM_DIR/bin/kill.sh" \
    || exit 17
echo "fi" \
     >> "$VM_DIR/bin/kill.sh" \
    || exit 17
echo "" \
     >> "$VM_DIR/bin/kill.sh" \
    || exit 17
echo "VM_PROCESS_NAME=\`ps --no-headers -q \$VM_PID -o comm= 2> /dev/null\`" \
     >> "$VM_DIR/bin/kill.sh" \
    || exit 17
echo "VM_MAYBE_QEMU=\`echo \"\$VM_PROCESS_NAME\" \\" \
     >> "$VM_DIR/bin/kill.sh" \
    || exit 17
echo "                   | grep '^qemu-'\`" \
     >> "$VM_DIR/bin/kill.sh" \
    || exit 17
echo "if test -z \"\$VM_MAYBE_QEMU\"" \
     >> "$VM_DIR/bin/kill.sh" \
    || exit 17
echo "then" \
     >> "$VM_DIR/bin/kill.sh" \
    || exit 17
echo "    echo \"ERROR $VM_NAME pid \$VM_PID (\$VM_PROCESS_NAME) does not appear to be a qemu command; aborting.\" >&2" \
     >> "$VM_DIR/bin/kill.sh" \
    || exit 17
echo "    exit 1" \
     >> "$VM_DIR/bin/kill.sh" \
    || exit 17
echo "fi" \
     >> "$VM_DIR/bin/kill.sh" \
    || exit 17
echo "" \
     >> "$VM_DIR/bin/kill.sh" \
    || exit 17
echo "echo \"Killing VM $VM_NAME pid \$VM_PID:\"" \
     >> "$VM_DIR/bin/kill.sh" \
    || exit 17
echo "kill \$VM_PID || exit 1" \
     >> "$VM_DIR/bin/kill.sh" \
    || exit 17
echo "" \
     >> "$VM_DIR/bin/kill.sh" \
    || exit 17
echo "echo \"SUCCESS killing VM $VM_NAME pid \$VM_PID\"" \
     >> "$VM_DIR/bin/kill.sh" \
    || exit 17
echo "exit 0" \
     >> "$VM_DIR/bin/kill.sh" \
    || exit 17
chmod u+x,go-rwx "$VM_DIR/bin/kill.sh" \
    || exit 17
echo "    OK $VM_DIR/bin/kill.sh"


# ======================================================================

rm -f "$VM_DIR/README.txt" \
    || exit 18
echo "+----------------------------------------------------------------------+" \
    | tee -a "$VM_DIR/README.txt" \
    || exit 18
echo "|                                                                      |" \
    | tee -a "$VM_DIR/README.txt" \
    || exit 18
echo "| Your VM '$VM_NAME' is ready to start:                                |" \
    | tee -a "$VM_DIR/README.txt" \
    || exit 18
echo "|                                                                      |" \
    | tee -a "$VM_DIR/README.txt" \
    || exit 18
echo "|     $VM_DIR/bin/start.sh" \
    | tee -a "$VM_DIR/README.txt" \
    || exit 18
echo "|                                                                      |" \
    | tee -a "$VM_DIR/README.txt" \
    || exit 18
echo "| After startup, you can ssh into your VM with:                        |" \
    | tee -a "$VM_DIR/README.txt" \
    || exit 18
echo "|                                                                      |" \
    | tee -a "$VM_DIR/README.txt" \
    || exit 18
echo "|     $VM_DIR/bin/ssh.sh" \
    | tee -a "$VM_DIR/README.txt" \
    || exit 18
echo "|                                                                      |" \
    | tee -a "$VM_DIR/README.txt" \
    || exit 18
echo "| (The error message 'Connection reset by peer' might appear during boo|" \
    | tee -a "$VM_DIR/README.txt" \
    || exit 18
echo "|   Wait a few seconds, then try it again.)                            |" \
    | tee -a "$VM_DIR/README.txt" \
    || exit 18
echo "| (The WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED! message        |" \
    | tee -a "$VM_DIR/README.txt" \
    || exit 18
echo "|   can be cleared by removing the VM's entry from your host's          |" \
    | tee -a "$VM_DIR/README.txt" \
    || exit 18
echo "|   ~/.ssh/known_hosts, or by deleting the whole ~/.ssh/known_hosts     |" \
    | tee -a "$VM_DIR/README.txt" \
    || exit 18
echo "|    file, then trying it again.                                        |" \
    | tee -a "$VM_DIR/README.txt" \
    || exit 18
echo "|   --------------------------------------------------------------------|" \
    | tee -a "$VM_DIR/README.txt" \
    || exit 18
echo ""

echo "SUCCESS Creating VM from $VM_FILE."
exit 0
