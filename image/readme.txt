RED Brick Linux Image
=====================

The RED Brick uses as special Linux image.

Building the Image
------------------

Requires a recent Debian or Ubuntu installation with Internet connection.

First run

 ./prepare-host.sh

to install required tools. Next run

 ./update-source.sh

to get or update the kernel and u-boot source code. Now the source can be
compiled, run

 ./compile-source.sh <config-name>

The <config-name> option selects the image configuration to use. See the
image_<config-name>.conf files in the config directory for available
configurations. For example:

 ./compile-source.sh full

Finally run

 sudo ./make-image.sh <config-name>

which creates the image file in the output directory. This can be transfered
to an SD card now.
