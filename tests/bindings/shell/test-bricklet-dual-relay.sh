#!/bin/sh
# connects to localhost:4223 by default, use --host and --port to change it

# change to your UID
uid=xyz

# Turn both relays off and on
tinkerforge call dual-relay-bricklet $uid set-state false false
sleep 1
tinkerforge call dual-relay-bricklet $uid set-state true true
