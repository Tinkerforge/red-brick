RED Brick Linux Image
=====================

The RED Brick uses as special Linux image.

Requirements
------------

This scripts require a recent Debian or Ubuntu installation with Internet
connection. Also make sure that the filesystem you're running this on is not
mounted with the ``nodev`` or ``noexec`` options as they hinder the root-fs
generation process. If you're using a separate partition for ``/home`` then it
is likely to be mounted with ``nodev`` and ``noexec``. In this case an easy
workaround is to build the image in a directory that is mounted without this
options, or to remount ``/home`` without this options. Building the image might
also not work inside an encrypted home directory.

In Ubuntu 14.04 the multistrap package has a bug. The ``/usr/sbin/multistrap``
script is written in Perl and it uses an undefined ``$forceyes`` variable in
one place. To fix the problem you need to edit ``/usr/sbin/multistrap`` and
remove ``$forceyes`` from it. If you don't have the multistrap package installed
yet, then the ``prepare-host.sh`` script in the next step will install it.

Building the Image
------------------

Because the Node.js and NPM packages are different between Ubuntu, Debian and
different Debian versions you have to install it manually for now. On Ubuntu and
Debian jessy and sid just install the ``npm`` package using::

 sudo apt-get install npm

On Debian wheezy follow this `setup instructions
<https://github.com/joyent/node/wiki/installing-node.js-via-package-manager>`__
to install Node.js including NPM. In short, run::

 curl -sL https://deb.nodesource.com/setup | sudo bash -
 sudo apt-get install nodejs

After installing Node.js and NPM run::

 ./prepare-host.sh

to install the remaining required tools and packages.

Next run::

 ./update-source.sh

to get or update the kernel and u-boot source code. Now the source can be
compiled, run::

 ./compile-source.sh <config-name>

The ``<config-name>`` option selects the image configuration to use. See the
``image_<config-name>.conf`` files in the config directory for available
configurations. For example::

 ./compile-source.sh full

The next step is to create the root-fs. This will download several Debian and
Raspbian packages. If you intent to create different root-fs it's useful to
setup apt-cacher daemons to avoid downloading all the packages multiple times,
see the apt-cacher section below for further details. Whether you decided to
use apt-cacher or not the next step is the same::

 sudo ./make-root-fs.sh <config-name>

Finally, run::

 sudo ./make-image.sh <config-name>

which creates the image file in the ``./build/output`` directory.

Using apt-cacher
^^^^^^^^^^^^^^^^

The apt-cacher daemon acts as a local cache for an APT server. If you intent
to create multiple images it's useful to setup apt-cacher daemons to avoid
downloading all packages multiple times. To do this you have to install the
apt-cacher package (it's not installed by the ``prepare-host.sh`` script)::

 sudo apt-get install apt-cacher

If dpkg asks you how apt-cacher should be started, select "manual". Finally,
start the apt-cacher daemons by running::

 ./start-apt-cacher.sh

Now ``./make-root-fs.sh`` will automatically use the apt-cacher daemons instead
of directly downloading from the Debian and Raspbian APT servers.

Writing the Image to a SD card
------------------------------

The image can be transferred to an SD card with::

 sudo ./write-image-to-sd-card.sh <config-name> <device>

For example (assuming that ``/dev/sdb`` is your SD card)::

 sudo ./write-image-to-sd-card.sh full /dev/sdb

Now the SD card can be used to boot the RED Brick.

Using the Image
---------------

The default user name is ``tf`` with password ``tf``.

The full image runs a LXDE desktop on the HDMI interface. All images have a
serial console running on the USB OTG interface.

Editing Kernel Config
---------------------

First update the kernel sources::

  ./update-source.sh

Then run the edit script that starts the graphical config editor::

  ./edit-kernel-config.sh <config-name>

After you edited and saved the config changes close the config editor and the
edit script will take care of the rest.

Enable Serial Console for Debug Brick
-------------------------------------

In ``config/kernel/red_brick_*_defconfig`` add::

 console=ttyS0,115200

to ``CONFIG_CMDLINE`` and ensure that the following two are set::

 CONFIG_SW_DEBUG_UART=3
 CONFIG_DEBUG_LL=y

In ``patches/root-fs/{full|fast}/etc/inittab`` uncomment::

 T1:23:respawn:/sbin/getty --autologin tf -L ttyS0 115200 vt100

In ``/etc/securetty`` uncomment::

 ttyS0
