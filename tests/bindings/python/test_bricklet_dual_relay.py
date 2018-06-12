#!/usr/bin/env python
# -*- coding: utf-8 -*-  

HOST = "localhost"
PORT = 4223
UID = "xyz" # Change to your UID

import time

from tinkerforge.ip_connection import IPConnection
from tinkerforge.bricklet_dual_relay import DualRelay

if __name__ == "__main__":
    ipcon = IPConnection() # Create IP connection
    dr = DualRelay(UID, ipcon) # Create device object

    ipcon.connect(HOST, PORT) # Connect to brickd
    # Don't use device before ipcon is connected

    # Turn both relays off and on
    dr.set_state(False, False)
    time.sleep(1)
    dr.set_state(True, True)

    ipcon.disconnect()
