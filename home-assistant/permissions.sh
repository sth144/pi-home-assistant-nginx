#!/bin/bash

# Change ownership of the volume directory and its contents
sudo chown -R pi:pi ./config

# Set permissions to allow user pi to read and write
sudo chmod -R u+w ./config

