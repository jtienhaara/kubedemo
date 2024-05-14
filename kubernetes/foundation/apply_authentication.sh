#!/bin/sh

#
# https://github.com/ory/k8s/releases/tag/v0.39.1
#
# Apache 2.0 license:
#
# https://github.com/ory/k8s/blob/v0.39.1/LICENSE
#
#
# Note: Until we get to the platform layer, we leave all authentication
# enabled as "anonymous".  When we deploy the platform layer, we deploy
# identity management and then turn off anonymous access.
# (Later we add authorization by identity, too.)
#

#
# Note that the Helm Chart.yaml tagged 0.39.1 shows "0.39.0" as the version.
# https://github.com/ory/k8s/blob/v0.39.1/helm/charts/oathkeeper/Chart.yaml
#
ORY_OATHKEEPER_VERSION=0.40.6
ORY_OATHKEEPER_HELM_CHART_VERSION=0.39.1

echo "Installing authentication (ory oathkeeper)..."

FOUNDATION_DIR=`dirname $0`
KUBECONFIG=$HOME/.kube/kubeconfig-kubedemo.yaml

#
# OMG Ory Oathkeeper Maester DELIBERATELY DELETES oathkeeper-rules ConfigMap.
# And if oathkeeper-rules doesn't exist then the Oathkeeper Pod never spins up.
# So we have to create a ConfigMap called "oathkeeper-rules"
# AFTER we deploy Ory.
# Dumbdumbdumbdumbdumb
#
# 2024-05-14 now changed to ory-oathkeeper-rules somehow *headscratch*
#
echo "  Re-applying ory-oathkeeper-rules ConfigMap until Ory Oathkeeper starts up:"
# 60 minutes is a long time!
MAX_SECONDS=3600
TOTAL_SECONDS=0
SLEEP_SECONDS=60
while test $TOTAL_SECONDS -lt $MAX_SECONDS
do
    OATHKEEPER_STATUSES=`kubectl get pods \
                             --namespace auth \
                             --kubeconfig $KUBECONFIG \
                             | awk '
                                    $1 ~ /^ory-oathkeeper.*$/ {
                                        print $3;
                                    }
                                   '`
    OATHKEEPER_UNRUNNING=`echo "$OATHKEEPER_STATUSES" \
                              | grep -v '^Running$'`
    if test ! -z "$OATHKEEPER_STATUSES" \
            -a -z "$OATHKEEPER_UNRUNNING"
    then
        echo "    Ory Oathkeeper has started up successfully."
        break
    fi

    echo "  Applying oOry Oathkeeper access rules ConfigMap:"
    kubectl apply \
            --filename $FOUNDATION_DIR/authentication/ory-oathkeeper/resources/authentication-ory-oathkeeper-configmap.yaml \
            --kubeconfig $KUBECONFIG \
        || exit 1

    NEW_TOTAL_SECONDS=`expr $TOTAL_SECONDS + $SLEEP_SECONDS`
    TOTAL_SECONDS=$NEW_TOTAL_SECONDS
    if test $TOTAL_SECONDS -ge $MAX_SECONDS
    then
        break
    fi

    sleep $SLEEP_SECONDS
done

if test $TOTAL_SECONDS -ge $MAX_SECONDS
then
    echo "ERROR Failed to start Ory Oathkeeper authentication after $TOTAL_SECONDS seconds" >&2
    exit 1
fi

echo "SUCCESS Installing authentication (oathkeeper)."
exit 0
