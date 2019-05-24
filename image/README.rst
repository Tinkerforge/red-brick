
RED Brick Linux Image
=====================

Official RED Brick Linux image build system.

Requirements
------------

The RED Brick image build system is basically a set of shell scripts
executed in a specific order.

The preferred and convenient way to build the image is by using Docker.
In order to do so Docker must be properly installed on the system the
image is being built on.

These scripts require a recent Debian or Ubuntu installation with Internet
connection and at least 15GB free disk space. Make sure that the filesystem
on which you're executing the build process is not mounted with the ``nodev``
or the ``noexec`` options. These options hinder the root-fs generation process.
If you're using a separate partition for ``/home`` then it is likely to be mounted
with ``nodev`` and ``noexec``. In this case an easy workaround is to build the
image in a directory that is mounted without these options, or to remount the
``/home`` directory without these options. Building the image might also not work
inside an encrypted ``/home`` directory.

In Ubuntu 14.04 the multistrap package has a bug. The ``/usr/sbin/multistrap``
script is written in Perl and it uses an undefined ``$forceyes`` variable in
one place. To fix the problem you need to edit ``/usr/sbin/multistrap`` and
remove ``$forceyes`` from it.

Building the Image
------------------

To start the build process execute::

 ./build.sh <config-name>

The ``<config-name>`` option selects the image configuration to use.
See the ``image_<config-name>.conf`` files in the config directory for
available configurations.

For example::

 foo@bar:~$ ./build.sh full

This script will execute the other scripts in the right order. If you have Docker
installed then the script will automatically try to fetch the official Docker image
and try to build using the Docker container.

After this script has successfully finished excuting the generated image can be found
in the ``./build/output`` directory.

Of course the scripts involved in the build process can be individually executed if
that is required. These scripts are described in the following subsection.

Scripts
^^^^^^^

To prepare the system for building the image run::

 foo@bar:~$ ./prepare-host.sh

After the preparations are done to get or update the kernel and u-boot source run::

 foo@bar:~$ ./update-source.sh

Now the source can be compiled by running::

 foo@bar:~$ ./compile-source.sh <config-name>

The next step is to create the root file system. This process will download
several Debian packages. It's useful to setup ``apt-cacher`` to avoid downloading
all the packages multiple times, see the apt-cacher section below for further details.

Whether you decided to use apt-cacher or not the next step is the same::

 foo@bar:~$ sudo ./make-root-fs.sh <config-name>

Finally, run::

 foo@bar:~$ sudo ./make-image.sh <config-name>

which creates the image file in the ``./build/output`` directory.

Using apt-cacher
^^^^^^^^^^^^^^^^

The ``apt-cacher`` daemon acts as a local cache for an APT server. If you intend
to create multiple images it's useful to setup apt-cacher daemons to avoid
downloading all packages multiple times.

To do this you have to install the ``apt-cacher`` package (it's not installed
by the ``prepare-host.sh`` script)::

 foo@bar:~$ sudo apt-get install apt-cacher

If ``dpkg`` asks you how ``apt-cacher`` should be started, select "manual".

Finally start the ``apt-cacher`` daemons by running::

 foo@bar:~$ ./start-apt-cacher.sh

Now ``./make-root-fs.sh`` will automatically use the ``apt-cacher`` daemons
instead of directly downloading from the Debian APT servers.

Writing the Image to an SD Card
-------------------------------

The image can be transferred to an SD card with::

 sudo ./write-image-to-sd-card.sh <config-name> <device>

For example (assuming that ``/dev/sdb`` is your SD card)::

 foo@bar:~$ sudo ./write-image-to-sd-card.sh full /dev/sdb

Now the SD card can be used to boot the RED Brick.

Using the Image
---------------

The default user name is ``tf`` with password ``tf``.

The full image runs a LXDE desktop on the HDMI interface.
All images have a serial console running on the USB OTG
interface.

Enable Serial Console for Debug Brick
-------------------------------------

In ``config/kernel/boot.cmd`` replace the line::

 setenv arg_console console=tty1

with the following line::

 setenv arg_console console=serial,ttyS3

Then move the file to RED-Brick's ``/boot`` directory and execute the following commands::

 foo@bar:~$ cd /boot

 foo@bar:~$ sudo mkimage -C none -A arm -T script -d boot.cmd boot.scr

After these steps reboot the RED-Brick to get a serial console through a Debug Brick.
