#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from tinkerforge.ip_connection import IPConnection
from tinkerforge.bricklet_gps import GPS

import time
import datetime
from subprocess import Popen, PIPE
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

        self.enum_sema = Semaphore(0)
        self.gps_uid = None
        self.gps_time = None
        self.timer = None

    # go trough the functions to update date and time
    def __enter__(self):
        if self.is_ntp_present():
            return -1, None
        if not self.get_gps_uid():
            return -2, None
        if not self.get_gps_time():
            return -3, None
        if self.are_times_equal():
            return 1, self.gps_time
        if self.is_time_crazy():
            return -4, None
        if not self.set_linux_time():
            return -5, None

        return 0, self.gps_time

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
            self.timer = Timer(1, self.enum_sema.release)
            self.timer.start()
            self.enum_sema.acquire()
        except:
            return False

        return True

    def get_gps_time(self):
        if self.gps_uid == None:
            return False

        try:
            # Create GPS device object
            self.gps = GPS(self.gps_uid, self.ipcon)
            date, time = self.gps.get_date_time()

            yy = date % 100
            yy += 2000
            date //= 100
            mm = date % 100
            date //= 100
            dd = date

            time //= 1000
            ss = time % 100
            time //= 100
            mins = time % 100
            time //= 100
            hh = time

            self.gps_time = datetime.datetime(yy, mm, dd, hh, mins, ss)
        except:
            return False

        return True

    def are_times_equal(self):
        # Are we more then 3 seconds off?
        if abs(int(self.gps_time.strftime("%s")) - time.time()) > 3:
            return False

        return True

    def is_time_crazy(self):
        try:
            return self.gps_time.year < 2014
        except:
            return True


    def set_linux_time(self):
        if self.gps_time == None:
            return False

        try:
            # Set date as root
            command = ['/usr/bin/sudo', '-S']
            command.extend('/bin/date +%s -u -s @{0}'.format(self.gps_time.strftime("%s")).split(' '))
            Popen(command, stdout=PIPE, stdin=PIPE).communicate(SUDO_PASSWORD)
        except:
            return False

        return True

    def cb_enumerate(self, uid, connected_uid, position, hardware_version, 
                     firmware_version, device_identifier, enumeration_type):
        # If more then one GPS Bricklet is connected we will use the first one that we find
        if device_identifier == GPS.DEVICE_IDENTIFIER:
            self.gps_uid = uid
            self.enum_sema.release()

if __name__ == '__main__':
    with GPSTimeToLinuxTime() as (status, time):
        if status == 0:
            print("Updated time: {0}".format(str(time)))
        elif status == 1:
            print("Times are already equal: {0}".format(str(time)))
        else:
            print("Failed with status: {0}".format(status))
