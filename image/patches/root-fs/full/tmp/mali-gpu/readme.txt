libump
------

Packages are build from

  https://github.com/linux-sunxi/libump/commit/ec0680628744f30b8fac35e41a7bd8e23e59c39f

using this instructions

  http://linux-sunxi.org/Mali_binary_driver#From_source

libsunxi-mali-x11
-----------------

Packages are build from

  https://github.com/linux-sunxi/sunxi-mali/commit/d343311efc8db166d8371b28494f0f27b6a58724

using this instructions

  http://linux-sunxi.org/Mali_binary_driver#From_source


xserver-xorg-video-sunximali
----------------------------

fbturbo_drv.so was recompiled from

  https://github.com/ssvb/xf86-video-fbturbo/tree/0.4.0

with libump enabled to support X11 API version 18.

Since commit 5f964213123bf5517e7ece09baf4bdaaba60d973 fbturbo will automatically
try to load the g2d_23 kernel module. This module is not available for A10s/sun5i
as this SoC does not have the G2D hardware. Therefore, the X11 log will contain
this error message

  modprobe: FATAL: Module g2d_23 not found.

which can be ignored.
