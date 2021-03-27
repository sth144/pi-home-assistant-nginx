#!/bin/bash

export OVPN_DATA="ovpn_data_raspi"

# TODO: command line arg?
export CLIENT_NAME="Sean_iOS"

# add client with client name
docker run -v $HOME/Volumes/$OVPN_DATA:/etc/openvpn \
    --rm -it mjenz/rpi-openvpn easyrsa \
    build-client-full $CLIENT_NAME nopass

# generate client config with embedded certificates
docker run -v $HOME/Volumes/$OVPN_DATA:/etc/openvpn \
    --rm mjenz/rpi-openvpn ovpn_getclient $CLIENT_NAME > $CLIENT_NAME.ovpn

mv $CLIENT_NAME.ovpn certs/
