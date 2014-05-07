RED Brick Linux Image
=====================

Requires a recent Debian or Ubuntu installation with Internet connection.

First run

 sudo ./prepare-host.sh <CONFIG_FILE_PATH>

to install required tools.

Next run

 ./reset-source.sh <CONFIG_FILE_PATH>

to get the kernel and u-boot source code. Now the source can be compiled, run

 ./compile-source.sh <CONFIG_FILE_PATH>

Finally run

 sudo ./make-image.sh <CONFIG_FILE_PATH>

which creates the image file in the output directory.
This can be transfered to an SD card now.
