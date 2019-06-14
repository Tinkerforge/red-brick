#!/usr/bin/python3 -u

import os
import subprocess
import time
import traceback
from urllib.request import urlopen
from tinkerforge.ip_connection import IPConnection
from tinkerforge.brick_master import BrickMaster

def dmesg(message):
    with open('/dev/kmsg', 'w') as f:
        f.write(message + '\n')

def cb_enumerate(uid, connected_uid, position, hardware_version, firmware_version,
                 device_identifier, enumeration_type):
    global master_bricks

    if enumeration_type != IPConnection.ENUMERATION_TYPE_AVAILABLE:
        return

    if device_identifier != BrickMaster.DEVICE_IDENTIFIER:
        return

    master_bricks.add(uid)

# show all messages written to /dev/kmsg on tty1
os.system('echo 8 > /proc/sys/kernel/printk')

try:
    overall_success = True

    # check for 8 Master Bricks
    dmesg('>>> Stack:      Testing')

    ipcon = IPConnection()
    master_bricks = set()

    ipcon.connect('localhost', 4223)
    ipcon.register_callback(IPConnection.CALLBACK_ENUMERATE, cb_enumerate)
    ipcon.enumerate()

    time.sleep(1)

    if len(master_bricks) != 8:
        master_bricks = set()

        ipcon.enumerate()

        time.sleep(1)

    stack_success = len(master_bricks) == 8

    dmesg('>>> Stack:      {0}'.format('Success +++' if stack_success else 'Failure ---'))

    if not stack_success:
        overall_success = False

    # check for Adafruit 5" HDMI display
    dmesg('>>> USB:        Testing')

    usb_success = b'ID 04d8:0c02 Microchip Technology, Inc.' in subprocess.check_output('lsusb')

    dmesg('>>> USB:        {0}'.format('Success +++' if usb_success else 'Failure ---'))

    if not usb_success:
        overall_success = False

    # check Extensions
    dmesg('>>> Extensions: Testing')

    extension_types = set()

    for i in range(2):
        try:
            with open('/tmp/extension_position_{0}.conf'.format(i)) as f:
                for line in f.readlines():
                    if line.startswith('type = '):
                        extension_types.add(line.replace('type = ', '').strip())
        except FileNotFoundError:
            pass

    extension_success = extension_types == {'2', '4'}

    dmesg('>>> Extensions: {0}'.format('Success +++' if extension_success else 'Failure ---'))

    if not extension_success:
        overall_success = False

    # check network connectivity
    dmesg('>>> Network:    Testing')

    network_success = True

    try:
        urlopen('https://www.heise.de')
    except:
        traceback.print_exc()
        network_success = False

    dmesg('>>> Network:    {0}'.format('Success +++' if network_success else 'Failure ---'))

    if not network_success:
        overall_success = False

    # report overall result
    dmesg('===========================')
    dmesg('>>> Overall:    {0}\n'.format('Success +++' if overall_success else 'Failure ---'))
except Exception as e:
    traceback.print_exc()
    dmesg('### Internal Error: {0}\n'.format(e))
