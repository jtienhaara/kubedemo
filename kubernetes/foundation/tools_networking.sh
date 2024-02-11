#!/bin/sh

echo "Installing networking tools (such as netstat)..."

echo "  Checking sudo access:"
sudo echo "  Granted sudo access." \
    || exit 1


#
# net-tools contains networking troubleshooting tools, such as:
# - netstat
# E.g.:
#     netstat -l -t tcp
#
# netcat-openbsd includes:
# - nc
# E.g.:
#     echo 'GET /grafana' | nc 172.18.0.128 80
#     echo 'GET /grafana' | nc 10.42.0.101 80
#
# nmap includes:
# - nmap
# E.g.:
#     nmap -p 80 -vvv 172.18.0.128
#     nmap -p 80 -vvv 10.42.0.101
#
# tcpdump includes:
# - tcpdump
# E.g.:
#     sudo tcpdump --interface any -w tcpdump.pcap
#
sudo apt-get install -y net-tools netcat-openbsd nmap tcpdump \
    || exit 1

echo "SUCCESS Installing networking tools (such as netstat)."
exit 0
