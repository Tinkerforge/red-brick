HUAWEI E1750 - Old Orange Modem
===============================

* Qualcomm MSM6280, Qualcomm RTR6280 (mostly not relevant)
* ID 12d1:1001 Huawei Technologies Co., Ltd. E169/E620/E800 HSDPA Modem
* Works in Windows with provided software
* Works in Linux on RED Brick with any combination but frequently keeps disconnecting
* Doesn't work in Linux desktop machines in any configuration

4G SYSTEMS XSStick P14 - White Modem
====================================

* Qualcomm MSM6290, Qualcomm RTR6285 (mostly not relevant)
* ID 1c9e:f000 OMEGA TECHNOLOGY
* Works in Windows with provided software
* Works in Linux if connected to a powered hub (with or without power) but not if directly connected to system USB port. The problem is reported by spurious changes on the TTY interface. Most probably is fixable by patching sakis3g source.

QUALCOMM INCORPORATED E1750 - New Orange Modem
==============================================

* Qualcomm MSM7600, Qualcomm PM7500 (mostly not relevant), Qualcomm RTR6285 (mostly not relevant)
* ID 12d1:1001 Huawei Technologies Co., Ltd. E169/E620/E800 HSDPA Modem
* Works in Windows with provided software
* Seems to connect on Linux desktop machines but only when connected to powered hub and even that randomly fails
* Doesn't work in Linux on any machine in any combination (fails at the stage when the tool asks for SIM PIN status). The problem is how AT command responses are sent by the modem and sakis3g source needs some fixes aswell. It is fixable by patching sakis3g source.

POTENTIAL MODEMS
================

* A list of Raspberry Pi verified modems (http://elinux.org/RPi_VerifiedPeripherals#USB_3G_Dongles)

Huawei
------

* E1750 (Qualcomm MSM6290 chipset)
* E173 (Qualcomm MSM6290 chipset)
* E1820 (Qualcomm MDM8200 chipset)
* E220 (Qualcomm MSM6280 chipset)
* E353 (Qualcomm 8200a chipset)
* E153/E160 (Qualcomm MSM6246 chipset)
* E169/E620/E800 (Qualcomm MSM7200 chipset)
* E303 (Qualcomm 6550 chipset) Someone made a Raspberry Pi access points with this modem using the same tools as we use in RED Brick (http://www.instructables.com/id/Raspberry-Pi-as-a-3g-Huawei-E303-wireless-Edima/?ALLSTEPS)

ZTE
---

* ZTE MF190S (Qualcomm MSM6290 chipset)
* ZTE MF626 (Qualcomm MSM6246 chipset)
* ZTE MF628 (Qualcomm MSM6280 chipset)
* ZTE MF70, It is a 3G modem + WiFi AP (Qualcomm MDM8200A chipset)
* ZTE Rocket MF591 (ICERA chipset)
