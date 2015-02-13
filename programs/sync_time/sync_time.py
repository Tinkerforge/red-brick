#!/usr/bin/env python2
# -*- coding: UTF-8 -*-

import os
import time

SUDO_PASSWORD = 'tf'

try:
    from watchdog.observers import Observer
    from watchdog.events import FileSystemEventHandler

    has_watchdog = True
except ImportError:
    has_watchdog = False

def set_time():
    try:
        with open('/tmp/sync-time/set') as f:
            data = f.read()

        os.system('echo "{0}" | sudo -S rm /tmp/sync-time/set 2> /dev/null'.format(SUDO_PASSWORD))

        timestamp, timezone = data.strip().split('\n')[0].split(' ')
        timestamp = int(timestamp) / 1000 # JavaScript timestamp is in milliseconds
        timezone = int(timezone) / 60 # JavaScript timezone is in minutes

        os.system('echo "{0}" | sudo -S date +%s -u -s @{1} 2> /dev/null'.format(SUDO_PASSWORD, timestamp))
        os.system('echo "%s" | sudo -S ln -sf /usr/share/zoneinfo/Etc/GMT%+d /etc/localtime 2> /dev/null' % (SUDO_PASSWORD, timezone))
    except:
        pass

if has_watchdog:
    class EventHandler(FileSystemEventHandler):
        def on_any_event(self, event):
            time.sleep(1)
            set_time()

    observer = Observer()
    observer.schedule(EventHandler(), path='/tmp/sync-time')
    observer.start()

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()

    observer.join()
else:
    while True:
        time.sleep(1)
        set_time()
