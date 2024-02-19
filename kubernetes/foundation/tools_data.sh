#!/bin/sh

echo "Installing data tools (such as jq)..."

echo "  Checking sudo access:"
sudo echo "  Granted sudo access." \
    || exit 1


#
# jq for parsing JSON, e.g.:
#
#     kubectl get configmap loki-dashboards-1 \
#         --output 'jsonpath={.data.loki-logs\.json}' \
#         --namespace monitoring \
#         --kubeconfig ~/.kube/kubeconfig-kubedemo.yaml \
#         | jq
#
# to pretty-print the otherwise humanly-indecipherable single line of JSON.
#
sudo apt-get install -y jq \
    || exit 1

echo "SUCCESS Installing data tools (such as jq)."
exit 0
