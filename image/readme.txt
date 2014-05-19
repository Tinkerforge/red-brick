RED Brick Linux Image
=====================

The RED Brick uses as special Linux image.

Building the Image
------------------

This requires a recent Debian or Ubuntu installation with Internet connection.
Also make sure that the filesystem you're running this on is not mounted with
the nodev or noexec options as they hinder the root-fs generation process.

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

The next step is to create the root-fs. This will download several Debian and
Raspbian packages. If you intent to create different root-fs it's useful to
setup apt-cacher daemons to avoid downloading all the packages multiple times,
see the apt-cacher section below for further details. Whether you decided to
use apt-cacher or not the next step is the same:

 sudo ./make-root-fs.sh <config-name>

Finally, run

 sudo ./make-image.sh <config-name>

which creates the image file in the ./build/output directory.

Writing the Image to a SD card
------------------------------

The image can be transfered to an SD card now with

 sudo ./write-image.sh <config-name> <device>

For example (assuming that /dev/sdb is your SD card):

 sudo ./write-image.sh full /dev/sdb

Using apt-cacher
----------------

The apt-cacher daemon acts as a local cache for an APT server. If you intent
to create multiple images it's useful to setup apt-cacher daemons to avoid
downloading all packages multiple times. To do this you have to install the
apt-cacher package (it's not installed by the prepare-host.sh script):

 sudo apt-get install apt-cacher

If dpkg asks you how apt-cacher should be started, select "manual". Finally,
start the apt-cacher daemons by running

 ./start-apt-cacher.sh

Now ./make-image.sh will automatically use the apt-cacher daemons instead of
directly downloading from the Debian and Raspbian APT servers.
