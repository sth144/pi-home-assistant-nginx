#!/bin/bash

export OVPN_DATA="ovpn_data_raspi"
export OVPN_SERVER="192.168.1.243"

# Create etc data volume
docker volume create --name $OVPN_DATA

# Initialize config files and certificates (prompts for passphrase)
docker run -v $HOME/Volumes/$OVPN_DATA:/etc/openvpn \
    --rm mjenz/rpi-openvpn ovpn_genconfig \
    -u udp://$OVPN_SERVER

# Open config file with vim (change DNS settings)
docker run -v $HOME/Volumes/$OVPN_DATA:/etc/openvpn \
    --rm -it arm32v6/alpine vi /etc/openvpn/openvpn.conf

# Initialize private key
docker run -v $HOME/Volumes/$OVPN_DATA:/etc/openvpn \
    --rm -it mjenz/rpi-openvpn ovpn_initpki

# Start OpenVPN server process (should be able to use docker compose)
docker run -v $HOME/Volumes/$OVPN_DATA:/etc/openvpn \
    -d -p 1194:1194/udp --cap-add=NET_ADMIN --name openvpn \
    --privileged --restart unless-stopped mjenz/rpi-openvpn

