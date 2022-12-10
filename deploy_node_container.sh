#!/bin/bash
# check if we supplied the correct arguments
if [ -z "$1" ]
  then
    echo "No container argument supplied"
    exit 1
fi

if [ -z "$2" ]
  then
    echo "No subdomain argument supplied"
    exit 1
fi

# assign the first incoming var as the name of the container
cn=$1
domain=$2

# create a new LXD container with the specified name and image
lxc launch ubuntu:18.04 $cn

# poll the container untill it is finished starting up
lxc exec $cn -- bash -c 'while [ "$(systemctl is-system-running 2>/dev/null)" != "running" ] && [ "$(systemctl is-system-running 2>/dev/null)" != "degraded" ]; do :; done'

# install Node.js and npm on the container
lxc exec $cn -- sudo snap install node --channel=19/stable --classic

# retrieve the virtual network ip adress
vip="$(lxc exec $cn -- sudo hostname -I | cut -d ' ' -f1)"


# make a simple node server folder
lxc exec $cn -- sudo mkdir node-server
lxc exec $cn -- sudo sh -c "cat >> node-server/server.js" << EOF
var http = require('http');
http.createServer(function (req, res) {
  res.writeHead(200, {'Content-Type': 'text/plain'});
  res.end('Hello World\nfrom inside the sethdev container\n');
}).listen(8000, '$vip');
console.log('Server running at $vip:8000/');
EOF

# start the Node.js server on the container on port 8000
lxc exec $cn -- node node-server/server.js &

# add a new server block to the NGINX configuration file on the proxy container
lxc exec proxy -- sh -c "cat >> /etc/nginx/sites-enabled/$domain.sethvanwieringen.dev" << EOF

upstream $cn {
    server $vip:8000;
}

server {

    server_name $domain.sethvanwieringen.dev;

    location / {
        proxy_pass http://$cn;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# reload the NGINX configuration on the proxy container
lxc exec proxy -- nginx -s reload