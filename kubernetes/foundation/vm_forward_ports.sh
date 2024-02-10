#!/bin/sh

echo "VM forwarding ports so that the kubedemo cluster is reachable..."

CLUSTER_DIR=/cloud-init/kubernetes/foundation/cluster
KUBECONFIG=$HOME/.kube/kubeconfig-kubedemo.yaml

echo "    Checking sudo access..."
sudo echo "    sudo access granted." \
    || exit 1

DATE_TIME=`date '+%Y%m%d%H%M%S'`
RUN_DIR=`dirname $0`
IPTABLES_BACKUP_FILE=/etc/sysconfig/iptables.$DATE_TIME.backup

#
# Route ports from the VM (or machine) in which this runs to the
# LoadBalancer running inside the kind cluster, so that we can
# point a browser to http://localhost:80 from the VM's host,
# have it routed through the VM via iptables to the Docker exposed
# port, and into the cluster to reach our apps.
#
# NOTE: We could do the same thing with the Kubernetes API port (6443),
# but we don't.  All kubectl commands must be executed from within
# this VM.  It acts as a crude demo kind of bastion server.
#
LOAD_BALANCER_IP_ADDRESS=`kubectl get service istio-ingressgateway \
                              --namespace istio-system \
                              --output jsonpath='{.status.loadBalancer.ingress[0].ip}' \
                              --kubeconfig $KUBECONFIG`
if test $? -ne 0 \
        -o -z "$LOAD_BALANCER_IP_ADDRESS"
then
    echo "ERROR Could not determine the IP address of the kubedemo cluster LoadBalancer Service.  Does Service istio-ingressgateway exist in namespace istio-system?  Does it have an external IP?" >&2
    exit 1
fi

echo "    Guessing external-facing network interfaces to route at firewall..."
EXTERNAL_INTERFACES=`
    /sbin/ifconfig \
        | awk '
               BEGIN {
                   network_interface = "";
                   is_external = "false";
               }
               $0 ~ /^[a-zA-Z0-9].*$/ {
                   network_interface = $1;
                   gsub(/:$/, "", network_interface);
                   is_external = "false";
               }
               network_interface ~ /^en[0-9]*$/ {
                   is_external = "true";
               }
               network_interface ~ /^eno[0-9]*[0-9]*$/ {
                   is_external = "true";
               }
               network_interface ~ /^enp[0-9]*s[0-9]*$/ {
                   is_external = "true";
               }
               network_interface ~ /^eth[0-9]*$/ {
                   is_external = "true";
               }
               network_interface ~ /^wlan[0-9]*$/ {
                   is_external = "true";
               }
               is_external == "true" {
                   print network_interface;
               }
               {
                   network_interface = "";
                   is_external = "false";
               }
              '`
EXIT_CODE=$?
echo "      Network interfaces to route:"
echo "$EXTERNAL_INTERFACES" \
    | sed 's|^\(.*\)$|        \1|'
if test $EXIT_CODE -ne 0 \
        -o -z "$EXTERNAL_INTERFACES"
then
    echo "ERROR Could not determine external network interfaces to route ($EXTERNAL_INTERFACES)" >&2
    exit 1
fi

INTERFACES_ONE_LINE=`echo "$EXTERNAL_INTERFACES" \
                         | awk '
                                {
                                    printf $1 " ";
                                }
                               '`

LOOPBACK_INTERFACE="lo"

echo "    Backing up old iptables rules to $IPTABLES_BACKUP_FILE"
sudo mkdir -p /etc/sysconfig \
    || exit 1
sudo iptables-save \
     > /tmp/iptables.$DATE_TIME.backup \
    || exit 1
sudo mv -f /tmp/iptables.$DATE_TIME.backup $IPTABLES_BACKUP_FILE \
    || exit 1

#
# For details see:
#
#     man iptables
#     man iptables-extensions (DNAT, MASQUERADE)
#

#
# Purge all PREROUTING and POSTROUTING rules in the nat table.
#
echo "    Purge all PREROUTING and POSTROUTING rules in the nat table..."
sudo iptables -t nat -F PREROUTING \
    || exit 2
sudo iptables -t nat -F POSTROUTING \
    || exit 2

#
# We'll use NAT to route incoming HTTP requests to the kind LoadBalancer,
# which has a Docker-exposed port, on port 80.
#
# Postrouting allows us to pretend communications are happening with
# this VM, not with the Docker IP address of the LoadBalancer Service
# in the kubedemo cluster.
#
echo "  Preroute HTTP/80 traffic to kubedemo LoadBalancer $LOAD_BALANCER_IP_ADDRESS..."
for NETWORK_INTERFACE in $EXTERNAL_INTERFACES $LOOPBACK_INTERFACE
do
    sudo iptables -t nat -A PREROUTING -i "$NETWORK_INTERFACE" -p tcp \
             --dport 80 -j DNAT --to-destination $LOAD_BALANCER_IP_ADDRESS:80 \
        || exit 3
done

echo "  Masquerade VM traffic as this host..."
for NETWORK_INTERFACE in $EXTERNAL_INTERFACES $LOOPBACK_INTERFACE
do
    sudo iptables -t nat -A POSTROUTING -o "$NETWORK_INTERFACE" \
         -j MASQUERADE \
        || exit 6
done


#
# Permanently turn on IP forwarding in the OS.
#
# ???needed?  we'll see...


#
# Save the new configuration so that it will be applied on restart:
#
echo "    Save the new configuration so that it will be applied on restart..."
sudo iptables-save \
     > /tmp/iptables.$DATE_TIME.new \
    || exit 3

echo "------------------------------------------------------------------------"
cat /tmp/iptables.$DATE_TIME.new
echo "------------------------------------------------------------------------"

sudo mv -f /tmp/iptables.$DATE_TIME.new /etc/sysconfig/iptables \
    || exit 3

echo ""
echo "SUCCESS VM forwarding ports so that the kubedemo cluster is reachable."

exit 0
