#!/bin/bash

ROOT_UID="0"

# Check if running as root
if [ "$UID" -ne "$ROOT_UID" ]
then
    echo -e "\nError: You must be root to execute the script\n"
    exit 1
fi

# Getting the configuration variables
if [ "$#" -ne 1 ]; then
    echo -e "\nError: Too many or too few parameters (provide image configuration)\n"
    exit 1
fi
. $1

# Checking u-boot
if [ ! -e ./$UBOOT_SRC_DIR/spl/$UBOOT_IMAGE ]
then
    echo -e "\nError: Please build u-boot first\n"
    exit 1
fi
# Checking kernel and boot script
if [ ! -e ./$KERNEL_SRC_DIR/arch/arm/boot/$KERNEL_IMAGE ]
then
    echo -e "\nError: Please build the kernel first\n"
    exit 1
fi
if [ ! -e ./$OPTS_DIR/kernel/$KERNEL_SCRIPT_BIN ]
then
    echo -e "\nError: No boot script found\n"
    exit 1
fi
# Checking kernel modules
if [ ! -d ./$KERNEL_SRC_DIR/$KERNEL_MOD_DIR ]
then
    echo -e "\nError: Build kernel modules first\n"
    exit 1
fi
# Checking multistrap script
if [ ! -e ./$OPTS_DIR/root-fs/$MULTISTRAP_SCRIPT ]
then
    echo -e "\nError: Multistrap script not found\n"
    exit 1
fi
# Checking qemu support
if [ ! -e $QEMU_BIN ]
then
    echo -e "\nError: Install qemu support for ARM\n"
    exit 1
fi

# Cleaning up output directory
if [ -d ./$OUTPUT_DIR ]
then
    rm -vrf ./$OUTPUT_DIR
    mkdir ./$OUTPUT_DIR
else
    mkdir ./$OUTPUT_DIR
fi

# Cleaning up where rootfs will be generated
if [ -d ./$ROOT_DIR ]
then
    rm -vrf ./$ROOT_DIR
fi

# Setting up caching
if [ ! -d ./$DEB_CACHE_DIR ]
then
    mkdir ./$DEB_CACHE_DIR
else
    mkdir ./$ROOT_DIR
    mkdir -p ./$ROOT_DIR/var/cache/apt/archives
    cp -avr ./$DEB_CACHE_DIR/* ./$ROOT_DIR/var/cache/apt/archives/
fi

# Setting up output directory
if [ -d ./$OUTPUT_DIR ]
then
    rm -vrf $OUTPUT_DIR
    mkdir ./$OUTPUT_DIR
else
    mkdir ./$OUTPUT_DIR
fi

# Starting multistrap
echo -e "\nInfo: Starting multistrap\n"
multistrap -f ./$OPTS_DIR/root-fs/$MULTISTRAP_SCRIPT

# Copying qemu-arm-static to rootfs
echo -e "\nInfo: Copying qemu-arm-static\n"
cp $QEMU_BIN ./$ROOT_DIR/usr/bin/

# Copying config files to rootfs
echo -e "\nInfo: Copying config files to rootfs\n"
cp ./$OPTS_DIR/root-fs/securetty        ./$ROOT_DIR/etc/
cp ./$OPTS_DIR/root-fs/inittab          ./$ROOT_DIR/etc/
cp ./$OPTS_DIR/root-fs/hostname         ./$ROOT_DIR/etc/
cp ./$OPTS_DIR/root-fs/fstab            ./$ROOT_DIR/etc/
cp ./$OPTS_DIR/root-fs/modules          ./$ROOT_DIR/etc/
cp ./$OPTS_DIR/root-fs/passwd           ./$ROOT_DIR/etc/
cp ./$OPTS_DIR/root-fs/interfaces       ./$ROOT_DIR/etc/network/
cp ./$OPTS_DIR/root-fs/50-mali.rules    ./$ROOT_DIR/etc/udev/rules.d/

# Rootfs configuration
echo -e "\nInfo: Configuring the generated rootfs\n"
chroot ./$ROOT_DIR<<EOF
export LC_ALL=C LANGUAGE=C LANG=C
apt-get update
mount -t proc proc /proc
/var/lib/dpkg/info/dash.preinst install
dpkg --configure -a
sync
umount /proc
EOF

# Copying kernel modules to rootfs
echo -e "\nInfo: Copying kernel modules to rootfs\n"
cp -avr ./$KERNEL_SRC_DIR/$KERNEL_MOD_DIR/lib/modules/ ./$ROOT_DIR/lib/
cp -avr ./$KERNEL_SRC_DIR/$KERNEL_MOD_DIR/lib/firmware/* ./$ROOT_DIR/lib/firmware/

# Configuring boot splash
echo -e "\nInfo: Configuring boot splash image\n"
cp ./$OPTS_DIR/root-fs/tf-logo.png           ./$ROOT_DIR/etc/
cp ./$OPTS_DIR/root-fs/asplashscreen         ./$ROOT_DIR/etc/init.d/
cp ./$OPTS_DIR/root-fs/killasplashscreen     ./$ROOT_DIR/etc/init.d/
chroot ./$ROOT_DIR<<EOF
export LC_ALL=C LANGUAGE=C LANG=C
chmod a+x /etc/init.d/asplashscreen
chmod a+x /etc/init.d/killasplashscreen
insserv /etc/init.d/asplashscreen
insserv /etc/init.d/killasplashscreen
sync
EOF

# Setup Mali GPU
cp -avr ./$OPTS_DIR/root-fs/mali-gpu       ./$ROOT_DIR/tmp/
chroot ./$ROOT_DIR<<EOF
export LC_ALL=C LANGUAGE=C LANG=C
cd /tmp/mali-gpu
dpkg -i ./libdri2-1_1.0-2_armhf.deb
dpkg -i ./libsunxi-mali-x11_1.0-4_armhf.deb
dpkg -i ./libvdpau-sunxi_1.0-1_armhf.deb
dpkg -i ./libvpx0_0.9.7.p1-2_armhf.deb
dpkg -i ./sunxi-disp-test_1.0-1_armhf.deb
dpkg -i ./udevil_0.4.1-3_armhf.deb
dpkg -i ./xserver-xorg-video-sunximali_1.0-3_armhf.deb
sync
EOF

# Setting up XDM logo and desktop wallpaper
cp -avr ./$OPTS_DIR/root-fs/tf.xpm ./$ROOT_DIR/usr/share/X11/xdm/pixmaps/
cp -avr ./$OPTS_DIR/root-fs/tf-bw.xpm ./$ROOT_DIR/usr/share/X11/xdm/pixmaps/
cp -avr ./$OPTS_DIR/root-fs/Xresources ./$ROOT_DIR/etc/X11/xdm/
cp -avr ./$OPTS_DIR/root-fs/pcmanfm.conf ./$ROOT_DIR/etc/xdg/pcmanfm/LXDE/

# Install Node.JS and NPM
cp ./$OPTS_DIR/root-fs/node_0.10.26-1_armhf.deb      ./$ROOT_DIR/tmp/
chroot ./$ROOT_DIR<<EOF
export LC_ALL=C LANGUAGE=C LANG=C
cd /tmp
dpkg -i node_0.10.26-1_armhf.deb
rm -vrf ./node_0.10.26-1_armhf.deb
sync
EOF

# FIXME: For some strange reason the hack
# to get the version number is not working.
# So right now it is hard coded.
#chroot ./$ROOT_DIR<<EOF
#export LC_ALL=C LANGUAGE=C LANG=C
#echo "nameserver 8.8.8.8" > /etc/resolv.conf
#cd /tmp
#wget -N http://nodejs.org/dist/node-latest.tar.gz
#tar zxvf node-latest.tar.gz
#rm -vrf node-latest.tar.gz
#cd node-v*
#./configure
#node_full_name=${PWD##*/}
#node_version=${node_full_name:6}
#fakeroot checkinstall -y --install=no --pkgversion 0.10.26 make -j16 install
#dpkg -i node_*
#wget --no-check-certificate https://www.npmjs.org/install.sh
#chmod 777 install.sh
#./install.sh
#rm -vrf node-v*
#rm -vrf install.sh
#rm -vrf /etc/resolv.conf
#sync
#EOF

# Applying console settings
chroot ./$ROOT_DIR<<EOF
export LC_ALL=C LANGUAGE=C LANG=C
setupcon
sync
EOF

# Cleaning up APT cache
chroot ./$ROOT_DIR<<EOF
export LC_ALL=C LANGUAGE=C LANG=C
apt-get clean
sync
EOF

# Setting root password
chroot ./$ROOT_DIR<<EOF
export LC_ALL=C LANGUAGE=C LANG=C
passwd root
tf
tf
sync
EOF

# Enable BASH completion
chroot ./$ROOT_DIR<<EOF
export LC_ALL=C LANGUAGE=C LANG=C
. /etc/bash_completion
sync
EOF

# Removing plymouth
chroot ./$ROOT_DIR<<EOF
export LC_ALL=C LANGUAGE=C LANG=C
apt-get remove plymouth -y
apt-get purge plymouth -y
sync
EOF

# Setting up desktop wallpaper
chroot ./$ROOT_DIR<<EOF
rm -vrf /etc/alternatives/desktop-background
ln -s /etc/tf-logo.png /etc/alternatives/desktop-background
sync
EOF

# Setup fake-hwclock
chroot ./$ROOT_DIR<<EOF
export LC_ALL=C LANGUAGE=C LANG=C
insserv -r /etc/init.d/hwclock.sh
fake-hwclock
sync
EOF

# Removing qemu-arm-static from rootfs
echo -e "\nInfo: Removing qemu-arm-static from rootfs\n"
rm ./$ROOT_DIR$QEMU_BIN

# Creating empty image
echo -e "\nInfo: Creating empty image\n"
dd bs=$IMAGE_BS count=$IMAGE_COUNT if=/dev/zero of=./$OUTPUT_DIR/$IMAGE_NAME.img

# Setting up loop device for image
echo -e "\nInfo: Setting up loop device for image\n"
loop_dev=$(losetup -f)
losetup $loop_dev ./$OUTPUT_DIR/$IMAGE_NAME.img

# Partitioning image
echo -e "\nInfo: Partitioning the image\n"
fdisk $loop_dev <<EOF
p
o
n
p
1
20480

w
EOF

# Setting up loop device for image partition
echo -e "\nInfo: Setting up loop device for image partition\n"
loop_dev_p1=$(losetup -f)
losetup -o $((512*20480)) $loop_dev_p1 ./$OUTPUT_DIR/$IMAGE_NAME.img

# Formatting image partition
echo -e "\nInfo: Formatting image partitions\n"
mkfs.ext3 $loop_dev_p1

# Installing U-Boot, boot script and the kernel to the storage device
echo -e "\nInfo: Installing U-Boot to the storage device\n"
dd bs=512 seek=$UBOOT_DD_SEEK if=./$UBOOT_SRC_DIR/spl/$UBOOT_IMAGE of=$loop_dev

echo -e "\nInfo: Installing boot script to the storage device\n"
dd bs=512 seek=$SCRIPTBIN_DD_SEEK if=./$OPTS_DIR/kernel/$KERNEL_SCRIPT_BIN of=$loop_dev

echo -e "\nInfo: Installing the kernel to the storage device\n"
dd bs=512 seek=$KERNEL_DD_SEEK if=./$KERNEL_SRC_DIR/arch/arm/boot/$KERNEL_IMAGE of=$loop_dev

echo -e "\nInfo: Copying rootfs to the image\n"
umount /mnt
mount $loop_dev_p1 /mnt
cp -avr ./$ROOT_DIR/* /mnt
sync
umount $loop_dev_p1

# Release loop device
echo -e "\nInfo: Releasing loop device\n"
losetup -d $loop_dev
losetup -d $loop_dev_p1

sync

echo -e "\nInfo: Process finished\n"

exit 0
