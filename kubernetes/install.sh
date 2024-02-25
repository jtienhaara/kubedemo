#!/bin/sh

echo ""
echo ""
echo "Installing kubedemo..."

RUN_DIR=`dirname $0`

echo ""
echo ""
echo "+----------------------------------------------------------------------+"
echo "|                                                                      |"
echo "|                          kubedemo FOUNDATION                         |"
echo "|                                                                      |"
echo "+----------------------------------------------------------------------+"
$RUN_DIR/install_foundation.sh \
    || exit 1

echo ""
echo ""
echo "+----------------------------------------------------------------------+"
echo "|                                                                      |"
echo "|                           kubedemo PLATFORM                          |"
echo "|                                                                      |"
echo "+----------------------------------------------------------------------+"
$RUN_DIR/install_platform.sh \
    || exit 1


echo "SUCCESS Installing kubedemo."
exit 0
