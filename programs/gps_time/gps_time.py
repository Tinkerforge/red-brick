#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from tinkerforge.ip_connection import IPConnection
from tinkerforge.bricklet_gps import BrickletGPS
from tinkerforge.bricklet_gps_v2 import BrickletGPSV2

import sys
import time
import subprocess
from datetime import datetime, timedelta, timezone
from threading import Semaphore, Timer

HOST = "localhost"
PORT = 4223
SUDO_PASSWORD = b'tf\n'

class GPSTimeToLinuxTime:
    def __init__(self):
        # Create IP connection
        self.ipcon = IPConnection()

        # Connect to brickd
        self.ipcon.connect(HOST, PORT)
        self.ipcon.register_callback(IPConnection.CALLBACK_ENUMERATE, self.cb_enumerate)
        self.ipcon.enumerate()

        self.enumerate_handshake = Semaphore(0)
        self.gps_uid = None
        self.gps_class = None
        self.gps_has_fix_function = None
        self.gps_datetime = None
        self.gps_has_fix = None
        self.timer = None

    # go trough the functions to update date and time
    def __enter__(self):
        if self.is_ntp_present():
            return -1, None

        if not self.get_gps_uid():
            return -2, None

        if not self.get_gps_time():
            return -3, None

        if not self.gps_has_fix:
            return 2, None

        if self.are_times_equal():
            return 1, self.gps_time

        if not self.set_linux_time():
            return -5, None

        return 0, self.gps_datetime

    def __exit__(self, type, value, traceback):
        try:
            self.timer.cancel()
        except:
            pass

        try:
            self.ipcon.disconnect()
        except:
            pass

    def is_ntp_present(self):
        # FIXME: Find out if we have internet access and ntp is working, in
        #        that case we don't need to use the GPS time.
        return False

    def get_gps_uid(self):
        try:
            # Release semaphore after 1 second (if no GPS Bricklet is found)
            self.timer = Timer(1, self.enumerate_handshake.release)
            self.timer.start()
            self.enumerate_handshake.acquire()
        except:
            return False

        return True

    def get_gps_time(self):
        if self.gps_uid == None:
            return False

        try:
            self.gps = BrickletGPSV2(self.gps_uid, self.ipcon)
            self.gps_has_fix = self.gps_has_fix_function(self.gps)

            if not self.gps_has_fix:
                return True

            gps_date, gps_time = self.gps.get_date_time()

            gps_year = 2000 + (gps_date % 100)
            gps_date //= 100
            gps_month = gps_date % 100
            gps_date //= 100
            gps_day = gps_date

            gps_microsecond = 1000 * (gps_time % 1000)
            gps_time //= 1000
            gps_second = gps_time % 100
            gps_time //= 100
            gps_minute = gps_time % 100
            gps_time //= 100
            gps_hour = gps_time

            self.gps_datetime = datetime(gps_year, gps_month, gps_day,
                                         gps_hour, gps_minute, gps_second,
                                         gps_microsecond, tzinfo=timezone.utc)
        except:
            return False

        return True

    def are_times_equal(self):
        return False
        # Are we more than 1 seconds off?
        return abs((self.gps_datetime - self.local_datetime) / timedelta(seconds=1)) < 1

    def set_linux_time(self):
        if self.gps_datetime == None:
            return False

        try:
            # Set date as root
            timestamp = int((self.gps_datetime - datetime(1970, 1, 1, tzinfo=timezone.utc)) / timedelta(seconds=1) * 1000000000)
            command = ['/usr/bin/sudo', '-S', '-p', '', '/bin/date', '+%s.%N', '-u', '-s', '@{0}.{1:09}'.format(timestamp // 1000000000, timestamp % 1000000000)]
            subprocess.Popen(command, stdout=subprocess.PIPE, stdin=subprocess.PIPE).communicate(SUDO_PASSWORD)
        except:
            return False

        return True

    def cb_enumerate(self, uid, connected_uid, position, hardware_version,
                     firmware_version, device_identifier, enumeration_type):
        # If more then one GPS Bricklet is connected we will use the first one that we find
        if device_identifier == BrickletGPS.DEVICE_IDENTIFIER:
            self.gps_uid = uid
            self.gps_class = BrickletGPS
            self.gps_has_fix_function = lambda gps: gps.get_status().fix != gps.FIX_NO_FIX
            self.enumerate_handshake.release()
        elif device_identifier == BrickletGPSV2.DEVICE_IDENTIFIER:
            self.gps_uid = uid
            self.gps_class = BrickletGPSV2
            self.gps_has_fix_function = lambda gps: gps.get_status().has_fix
            self.enumerate_handshake.release()

if __name__ == '__main__':
    with GPSTimeToLinuxTime() as (status, gps_datetime):
        if status == 0:
            print("Updated time: {0}".format(gps_datetime.strftime('%Y-%m-%d %H:%M:%S.%f %Z')))
        elif status == 1:
            print("Times are already equal: {0}".format(gps_datetime.strftime('%Y-%m-%d %H:%M:%S.%f %Z')))
        elif status == 2:
            print("No Fix, no GPS time available")
            sys.exit(1)
        else:
            print("Failed with status: {0}".format(status))
            sys.exit(2)
