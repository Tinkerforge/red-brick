Get GPS location from SMS request
---------------------------------

This example demonstrates how GPS location can be reported via SMS if
you have a GPS Bricklet and a GSM modem connected to the RED Brick.
In the source file ``sms_location.py`` change the constant ``PIN_SIM``
according to your setup. If you have SIM card PIN disabled then you should
set the ``PIN_SIM`` constant to an empty string. By default sending ``tf:loc``
via SMS to the phone number of the SIM card being used with the GSM modem
one should get a SMS replied that reports the current location from the
GPS Bricklet.

Upload this program to the RED Brick using Brick Viewer's Program wizard
with the following program settings:

* 1 of 8:

  * Name: SMS Location
  * Language: Python

* 2 of 8:

  * Add directory that contains the script ``sms_location.py`` and the directory ``humod``

* 3 of 8:

  * Version 2.x.y
  * Start Mode: Script File
  * Script File: ``sms_location.py``

* 4 of 8: Add argument ``/dev/ttyUSB0``. Usually this is the case but depending on your modem it can be someother device file as well. If you see in log the message ``ERROR: Failed to initialze modem`` try changing this argument.
* 5 of 8: Default
* 6 of 8: Default
* 7 of 8: Nothing
* 8 of 8: Start Upload
