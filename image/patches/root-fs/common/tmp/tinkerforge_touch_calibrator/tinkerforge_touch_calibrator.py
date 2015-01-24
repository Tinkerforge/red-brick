#!/usr/bin/env python2
# -*- coding: utf-8 -*-

import os
import syslog
import subprocess

# Constants
DIALOG_NOTIFICATION_INFO = 1
DIALOG_NOTIFICATION_ERROR = 2
DIALOG_TITLE_INPUT = 'User Input | Tinkerforge Touch Calibrator'
DIALOG_TITLE_INFO = 'Information | Tinkerforge Touch Calibrator'
DIALOG_TITLE_ERROR = 'Error | Tinkerforge Touch Calibrator'
DIALOG_MESSAGE_ERROR_CALIBRATOR = 'Error: Calibration program unavailable'
DIALOG_MESSAGE_ERROR_HARDWARE = 'Error: No supported hardware found'
DIALOG_MESSAGE_ERROR_ABORTED = 'Error: Calibration process aborted'
DIALOG_MESSAGE_ERROR_FILE_WRITE = 'Error: Error occured while writing configuration file'
DIALOG_MESSAGE_ERROR_EMPTY_PASSWORD = 'Error: You must enter a password'
DIALOG_MESSAGE_INFO_CALIBRATION = 'Calibration applied and saved'
INPUT_DEVICE = ' "Microchip Technology Inc. AR1100 HID-MOUSE" '
CONFIG_FILE = '/usr/share/X11/xorg.conf.d/99-calibration.conf'

# Function for handling notifications
def handle_notification(title, message, notification_type):
    try:
        if notification_type == DIALOG_NOTIFICATION_INFO:
            cmd = '''/usr/bin/zenity --info --title "{0}" --text "{1}"'''.format(title, message)
        elif notification_type == DIALOG_NOTIFICATION_ERROR:
            cmd = '''/usr/bin/zenity --error --title "{0}" --text "{1}"'''.format(title, message)
        os.system(cmd)
    except Exception as e:
        syslog.syslog(syslog.LOG_ERR, e)
        exit(-1)

# Checking for dialog tool
if not os.path.isfile('/usr/bin/zenity'):
    syslog.syslog(syslog.LOG_ERR, 'Zenity not available')
    exit(-1)

# Ask for password
try:
    cmd = '''/usr/bin/zenity --title "{0}" --password'''.format(DIALOG_TITLE_INPUT)
    ps_get_password = subprocess.Popen(cmd,
                                       shell=True,
                                       stdout=subprocess.PIPE)

    if ps_get_password.returncode:
        handle_notification(DIALOG_TITLE_ERROR,
                            ps_get_devices.communicate()[1],
                            DIALOG_NOTIFICATION_ERROR)
        exit(-1)
    
    password = ps_get_password.communicate()[0].strip()

    if not password:
        handle_notification(DIALOG_TITLE_ERROR,
                            DIALOG_MESSAGE_ERROR_EMPTY_PASSWORD,
                            DIALOG_NOTIFICATION_ERROR)
        exit(-1)

except Exception as e:
    handle_notification(DIALOG_TITLE_ERROR, e, DIALOG_NOTIFICATION_ERROR)
    exit(-1)

# Checking for the calibrator
if not os.path.isfile('/usr/bin/xinput_calibrator'):
    handle_notification(DIALOG_TITLE_ERROR,
                        DIALOG_MESSAGE_ERROR_CALIBRATOR,
                        DIALOG_NOTIFICATION_ERROR)
    exit(-1)

# Get device ID and check
try:
    ps_get_devices = subprocess.Popen('/usr/bin/xinput_calibrator --list',
                                      shell=True,
                                      stdout=subprocess.PIPE)
    
    if ps_get_devices.returncode:
        handle_notification(DIALOG_TITLE_ERROR,
                            ps_get_devices.communicate()[1],
                            DIALOG_NOTIFICATION_ERROR)
        exit(-1)
except Exception as e:
    handle_notification(DIALOG_TITLE_ERROR, e, DIALOG_NOTIFICATION_ERROR)
    exit(-1)

ps_get_devices_stdout = ps_get_devices.communicate()[0]
lines = ps_get_devices_stdout.splitlines()
device_found = False

for l in lines:
    if INPUT_DEVICE not in l:
        continue

    line_split = l.strip().split(INPUT_DEVICE)

    if len(line_split) == 2:
        device_id_split = line_split[1].split('=')
        if len(device_id_split) == 2:
            device_found = True
            device_id = device_id_split[1]
            break

if not device_found:
    handle_notification(DIALOG_TITLE_ERROR,
                        DIALOG_MESSAGE_ERROR_HARDWARE,
                        DIALOG_NOTIFICATION_ERROR)
    exit(-1)

try:
    ps_xinput_calibrate = subprocess.Popen('/usr/bin/xinput_calibrator --device '+ device_id,
                                           shell=True,
                                           stdout=subprocess.PIPE)
    if ps_xinput_calibrate.returncode:
        handle_notification(DIALOG_TITLE_ERROR,
                            ps_xinput_calibrate.communicate()[1],
                            DIALOG_NOTIFICATION_ERROR)
        exit(-1)
except Exception as e:
    handle_notification(DIALOG_TITLE_ERROR, e, DIALOG_NOTIFICATION_ERROR)
    exit(-1)

ps_xinput_calibrate_stdout = ps_xinput_calibrate.communicate()[0]
ps_xinput_calibrate_stdout_split = ps_xinput_calibrate_stdout.split('Section "InputClass"')

if len(ps_xinput_calibrate_stdout_split) != 2:
    handle_notification(DIALOG_TITLE_ERROR,
                        DIALOG_MESSAGE_ERROR_ABORTED,
                        DIALOG_NOTIFICATION_ERROR)
    exit(-1)

config_content = 'Section "InputClass"'+ps_xinput_calibrate_stdout_split[1]

try:
    cmd = '''/bin/echo "{0}" | /usr/bin/sudo -S sh -c \'/bin/echo -e "{1}" >  {2}\''''.format(password,
                                                                                              config_content.replace('"', '\\"'),
                                                                                              CONFIG_FILE)

    if os.system(cmd):
        handle_notification(DIALOG_TITLE_ERROR,
                            DIALOG_MESSAGE_ERROR_FILE_WRITE,
                            DIALOG_NOTIFICATION_ERROR)
        exit(-1)
    handle_notification(DIALOG_TITLE_INFO,
                        DIALOG_MESSAGE_INFO_CALIBRATION,
                        DIALOG_NOTIFICATION_INFO)
except Exception as e:
    handle_notification(DIALOG_TITLE_ERROR, e, DIALOG_NOTIFICATION_ERROR)
    exit(-1)
