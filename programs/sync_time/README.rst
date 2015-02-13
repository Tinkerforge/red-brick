Synchronize system time via web browser
---------------------------------------

If you can't use NTP (i.e. the RED Brick does not have Internet access) or a
GPS Bricklet to set a proper system time, you can manually synchronize it using
your web browser.

Upload this program to the RED Brick using Brick Viewer's New Program wizard.
The following program settings will provide you with website for system time
synchronization:

* 1 of 8:

  * Name: Sync Time
  * Language: Python

* 2 of 8:

  * Add ``sync_time.py``, ``index.py`` and ``jquery.js``

* 3 of 8:

  * Version 2.x.y
  * Start Mode: Script File
  * Script File: ``sync_time.py``

* 4 of 8: Nothing
* 5 of 8: Default
* 6 of 8:

  * Mode: Always
  * Continue After Error: Enabled

* 7 of 8: Nothing
* 8 of 8: Start Upload

Now you can open a web browser at::

 http://<red-brick-address>/programs/Sync_Time/bin/

and synchronize the RED Brick system time to your local time.
