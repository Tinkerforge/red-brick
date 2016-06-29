#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from tinkerforge.ip_connection import IPConnection
from tinkerforge.bricklet_real_time_clock import BrickletRealTimeClock

import time
import datetime
from subprocess import Popen, PIPE
from threading import Semaphore, Timer

HOST = "localhost"
PORT = 4223
SUDO_PASSWORD = b'tf\n'

class RTCTimeToLinuxTime:
    def __init__(self):
        # Create IP connection
        self.ipcon = IPConnection()

        # Connect to brickd
        self.ipcon.connect(HOST, PORT)
        self.ipcon.register_callback(IPConnection.CALLBACK_ENUMERATE, self.cb_enumerate)
        self.ipcon.enumerate()

        self.enum_sema = Semaphore(0)
        self.rtc_uid = None
        self.rtc_time = None
        self.timer = None

    # go trough the functions to update date and time
    def __enter__(self):
        if self.is_ntp_present():
            return -1, None
        if not self.get_rtc_uid():
            return -2, None
        if not self.get_rtc_time():
            return -3, None
        if self.are_times_equal():
            return 1, self.rtc_time
        if not self.set_linux_time():
            return -4, None

        return 0, self.rtc_time

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
        #        that case we don't need to use the RTC time.
        return False

    def get_rtc_uid(self):
        try:
            # Release semaphore after 1 second (if no Real-Time Clock Bricklet is found)
            self.timer = Timer(1, self.enum_sema.release)
            self.timer.start()
            self.enum_sema.acquire()
        except:
            return False

        return True

    def get_rtc_time(self):
        if self.rtc_uid == None:
            return False

        try:
            # Create Real-Time Clock device object
            self.rtc = BrickletRealTimeClock(self.rtc_uid, self.ipcon)
            year, month, day, hour, minute, second, centisecond, _ = self.rtc.get_date_time()
            self.rtc_time = datetime.datetime(year, month, day, hour, minute, second, centisecond * 10000)
        except:
            return False

        return True

    def are_times_equal(self):
        # Are we more then 3 seconds off?
        if abs(int(self.rtc_time.strftime("%s")) - time.time()) > 3:
            return False

        return True

    def set_linux_time(self):
        if self.rtc_time == None:
            return False

        try:
            # Set date as root
            command = ['/usr/bin/sudo', '-S', '/bin/date', self.rtc_time.strftime('%m%d%H%M%Y.%S')]
            Popen(command, stdout=PIPE, stdin=PIPE).communicate(SUDO_PASSWORD)
        except:
            return False

        return True

    def cb_enumerate(self, uid, connected_uid, position, hardware_version,
                     firmware_version, device_identifier, enumeration_type):
        # If more then one Real-Time Clock Bricklet is connected we will use the first one that we find
        if device_identifier == BrickletRealTimeClock.DEVICE_IDENTIFIER:
            self.rtc_uid = uid
            self.enum_sema.release()

if __name__ == '__main__':
    with RTCTimeToLinuxTime() as (status, time):
        if status == 0:
            print("Updated time: {0}".format(str(time)))
        elif status == 1:
            print("Times are already equal: {0}".format(str(time)))
        else:
            print("Failed with status: {0}".format(status))
