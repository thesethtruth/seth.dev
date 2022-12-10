#!/bin/bash
# check if we supplied the correct arguments
if [ -z "$1" ]; then
    echo "No container argument supplied"
    exit 1
fi

if [ -z "$2" ]; then
    echo "No subdomain argument supplied"
    exit 1
fi

# assign the first incoming var as the name of the container
cn=$1
domain=$2

# stop and remove the serving container
lxc stop $cn
lxc delete $cn

# remove domain nginx config on the proxy container
lxc exec proxy -- sudo rm /etc/nginx/sites-enabled/$domain.sethvanwieringen.dev

# reload the NGINX configuration on the proxy container
lxc exec proxy -- nginx -s reload
