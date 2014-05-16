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

The next step is to create the image file. This will download several Debian
and Raspbian package to build the root-fs. If you intent to create multiple
images it's useful to setup apt-cacher daemons to avoid downloading all the
packages multiple times, see the apt-cacher section below for further details.
Whether you decided to use apt-cacher or not the next step is the same:

 sudo ./make-image.sh <config-name>

this creates the image file in the ./build/output directory.

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
