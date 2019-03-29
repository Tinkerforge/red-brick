#!/bin/sh
# connects to localhost:4223 by default, use --host and --port to change it

# change to your UID
uid=xyz

# Turn both relays off and on
tinkerforge call industrial-dual-relay-bricklet $uid set-value false false
sleep 1
tinkerforge call industrial-dual-relay-bricklet $uid set-value true true
