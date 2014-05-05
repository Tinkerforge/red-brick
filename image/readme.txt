RED Brick Linux Image
=====================

Requires a recent Debian or Ubuntu installation.

First run

 sudo prepare-host.sh

to install required tools.

Next run

 reset-source.sh ./config/image_full.conf

to get the kernel and u-boot source code. Now the source can be compiled, run

 compile-source.sh ./config/image_full.conf

Finally run

 sudo make-image.sh ./config/image_full.conf

which creates the image file in the output directory. This can be transfered
to an SD card now.
