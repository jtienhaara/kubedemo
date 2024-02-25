#!/bin/sh

echo "Installing the platform for a Kubernetes demo..."

RUN_DIR=`dirname $0`

# We don't need sudo access for the platform layer.

echo "  Installing platform components:"

echo "    Applying database:"
$RUN_DIR/platform/apply_database.sh \
    || exit 7


echo "SUCCESS Installing the platform for a Kubernetes demo."
exit 0
