#!/bin/sh

KUBECONFIG=$HOME/.kube/kubeconfig-kubedemo.yaml

kubectl get pods \
        --all-namespaces \
        --kubeconfig $KUBECONFIG \
    | awk '
           $4 != "Running" && $4 != "Completed" {
               print $0;
           }
          ' \
              || exit 1

exit 0
