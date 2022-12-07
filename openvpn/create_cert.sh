#!/bin/bash

CLIENTNAME=$1

docker-compose run --rm openvpn easyrsa build-client-full $CLIENTNAME nopass
docker-compose run --rm openvpn ovpn_getclient $CLIENTNAME > certs/$CLIENTNAME.ovpn
