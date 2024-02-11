#!/bin/sh

CLUSTER_DIR=/cloud-init/kubernetes/foundation/cluster
KUBECONFIG=$HOME/.kube/kubeconfig-kubedemo.yaml

#
# Route ports from the VM (or machine) in which this runs to the
# LoadBalancer running inside the kind cluster, so that we can
# point a browser to http://localhost:7080 from the VM's host,
# have it routed through the VM via iptables to the Docker exposed
# port, and into the cluster to reach our apps.
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

# !!!
echo "  Downloading caddy:"
wget https://github.com/caddyserver/caddy/releases/download/v2.7.6/caddy_2.7.6_linux_amd64.deb \
    || exit 1

echo "  Installing caddy:"
sudo dpkg -i caddy_2.7.6_linux_amd64.deb \
    || exit 1

for TRY_NUM in 1 2 3
do
    if test $TRY_NUM -gt 1
    then
        echo "    Sleeping:"
        sleep `expr $TRY_NUM * 2` \
            || exit 1
    fi

    echo "  Stopping caddy:"
    sudo systemctl stop caddy \
        && break
done

echo "  Creating Caddyfile content:"
CADDY_FILE=`cat -- << END_OF_CADDY_FILE
:8080 {
    reverse_proxy $LOAD_BALANCER_IP_ADDRESS:80
}
END_OF_CADDY_FILE`

echo "  Writing /etc/caddy/Caddyfile:"
sudo sh -c "echo '$CADDY_FILE' > /etc/caddy/Caddyfile" \
    || exit 1

echo "  Starting caddy:"
sudo systemctl start caddy \
    || exit 1

#caddy reverse-proxy \
#      --from :8080 \
#      --to 172.18.0.128:80 \
#    || exit 1

echo "SUCCESS"
exit 0
