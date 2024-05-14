#!/bin/sh

RUN_DIR=`dirname $0`

KUBECONFIG=$HOME/.kube/kubeconfig-kubedemo.yaml

kubectl get pods \
        --all-namespaces \
        --kubeconfig $KUBECONFIG \
    | awk '
           $4 != "Running" && $4 != "Completed" {
               print $0;
           }
           $4 == "Running" {
               actual_ready_containers = $3;
               expected_ready_containers = $3;
               gsub(/\/[0-9]*$/, "", actual_ready_containers)
               gsub(/^[0-9]*\//, "", expected_ready_containers)
               if (actual_ready_containers != expected_ready_containers) {
                   print $0;
               }
           }
          ' \
              | $RUN_DIR/filter_out_successful_jobs.sh
if test $? -ne 0
then
    exit 1
fi

exit 0
