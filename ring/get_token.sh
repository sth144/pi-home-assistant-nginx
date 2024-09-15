#!/bin/bash

docker run -it --rm --mount type=bind,source=/home/pi/Volumes/ring,target=/data --entrypoint /app/ring-mqtt/init-ring-mqtt.js tsightler/ring-mqtt

