RED Brick Linux Image
=====================

Requires a recent Debian or Ubuntu installation with Internet connection.

First run

 ./prepare-host.sh

to install required tools.

Next run

 ./reset-source.sh

to get the kernel and u-boot source code. Now the source can be compiled, run

 ./compile-source.sh <image-config-name>

The <image-config-name> option selects the image configuration to use. See
the image_<image-config-name>.conf files in the config directory for available
image configurations. For example:

 ./compile-source.sh full

Finally run

 sudo ./make-image.sh <image-config-name>

which creates the image file in the output directory. This can be transfered
to an SD card now.
