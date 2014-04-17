#!/bin/bash

ROOT_UID="0"

# Check if running as root
if [ "$UID" -ne "$ROOT_UID" ]
then
    echo -e "\nError: You must be root to execute the script\n"
    exit 1
fi

# Variables
OPTS_DIR="optimizations"
ROOT_DIR="root-fs"

UBOOT_SRC_DIR="u-boot-sunxi"
UBOOT_IMAGE="sunxi-spl.bin"

KERNEL_SRC_DIR="linux-sunxi"
KERNEL_MOD_DIR="out"
KERNEL_IMAGE="uImage"
BOOT_SCRIPT="script_red_brick.bin"

QEMU_BIN="/usr/bin/qemu-arm-static"
MULTISTRAP_SCRIPT="multistrap-stable.conf"

UBOOT_DD_SEEK=16
SCRIPTBIN_DD_SEEK=80
KERNEL_DD_SEEK=224

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
if [ ! -e ./$OPTS_DIR/kernel/$BOOT_SCRIPT ]
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

# Getting storage device
echo -e "\n"
read -p "Storage device to prepare(e.g sdb or mmcblk0): " STORAGE_DEVICE
echo -e "\n"

# Check if the device is there
if [ ! -e /dev/$STORAGE_DEVICE ]
then
    echo -e "\nError: Specified device not found\n"
    exit 1
fi

# Cleaning up where rootfs will be generated
echo -e "\nInfo: Cleaning up\n"
if [ -d ./$ROOT_DIR ]
then
    rm -vfr ./$ROOT_DIR
fi

# Starting multistrap
echo -e "\nInfo: Starting multistrap\n"
multistrap -f ./$OPTS_DIR/root-fs/$MULTISTRAP_SCRIPT

# Copying qemu-arm-static to rootfs
echo -e "\nInfo: Copying qemu-arm-static\n"
cp $QEMU_BIN ./$ROOT_DIR/usr/bin/

# Rootfs configuration
echo -e "\nInfo: Configuring the generated rootfs\n"
chroot ./$ROOT_DIR<<EOF
export LC_ALL=C LANGUAGE=C LANG=C
mount -t proc proc /proc
/var/lib/dpkg/info/dash.preinst install
dpkg --configure -a
EOF

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
chmod a+x /etc/init.d/asplashscreen
chmod a+x /etc/init.d/killasplashscreen
insserv /etc/init.d/asplashscreen
insserv /etc/init.d/killasplashscreen
sync
EOF

# Setup Mali GPU
cp -avr ./$OPTS_DIR/root-fs/mali-gpu       ./$ROOT_DIR/tmp/
chroot ./$ROOT_DIR<<EOF
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
cp -avr ./$OPTS_DIR/root-fs/rc.local ./$ROOT_DIR/etc/
chroot ./$ROOT_DIR<<EOF
chmod a+x /etc/rc.local
sync
EOF

# Building and install Node.JS and NPM
chroot ./$ROOT_DIR<<EOF
echo "nameserver 8.8.8.8" > /etc/resolv.conf
src=$(mktemp -d) && cd $src
wget -N http://nodejs.org/dist/node-latest.tar.gz
tar xzvf node-latest.tar.gz && cd node-v*
./configure
fakeroot checkinstall -y --install=no --pkgversion $(echo $(pwd) | sed -n -re's/.+node-v(.+)$/\1/p') make -j$(($(nproc)+1)) install
dpkg -i node_*
rm -vrf node_*
curl https://www.npmjs.org/install.sh | sh
rm -vrf /etc/resolv.conf
sync
EOF

# Removing qemu-arm-static from rootfs
echo -e "\nInfo: Removing qemu-arm-static from rootfs\n"
rm ./$ROOT_DIR$QEMU_BIN

# Check if the device is there
if [ ! -e /dev/$STORAGE_DEVICE ]
then
    echo -e "\nError: Specified device not found\n"
    exit 1
fi

# Preparing the storage
echo -e "\n"
read -p "Attention: Make sure the device $STORAGE_DEVICE is not mounted.
Press ENTER when ready"
echo -e "\n"

# Applying console settings
chroot ./$ROOT_DIR<<EOF
setupcon
sync
EOF

echo -e "\nInfo: Zeroing first 32MB of /dev/$STORAGE_DEVICE\n"
dd bs=1M count=32 if=/dev/zero of=/dev/$STORAGE_DEVICE

echo -e "\nInfo: Partitioning /dev/$STORAGE_DEVICE\n"

fdisk /dev/$STORAGE_DEVICE <<EOF
p
o
n
p
1
20480

w
EOF

if [ ${STORAGE_DEVICE:0:3} = "mmc" ]
then
    PARTITION_1="/dev/"$STORAGE_DEVICE"p1"
else
    PARTITION_1="/dev/"$STORAGE_DEVICE"1"
fi

# Checking partitions
if [ ! -e $PARTITION_1 ]
then
    echo -e "\nError: Partition 1 not found\n"
    exit 1
fi

echo -e "\nInfo: Formatting partitions\n"

mkfs.ext3 $PARTITION_1

# Installing U-Boot, boot script and the kernel to the storage device
echo -e "\nInfo: Installing U-Boot to the storage device\n"
dd bs=512 seek=$UBOOT_DD_SEEK if=./$UBOOT_SRC_DIR/spl/$UBOOT_IMAGE of=/dev/$STORAGE_DEVICE 

echo -e "\nInfo: Installing boot script to the storage device\n"
dd bs=512 seek=$SCRIPTBIN_DD_SEEK if=./$OPTS_DIR/kernel/$BOOT_SCRIPT of=/dev/$STORAGE_DEVICE

echo -e "\nInfo: Installing the kernel to the storage device\n"
dd bs=512 seek=$KERNEL_DD_SEEK if=./$KERNEL_SRC_DIR/arch/arm/boot/$KERNEL_IMAGE of=/dev/$STORAGE_DEVICE

echo -e "\nInfo: Installing rootfs to the storage device\n"
umount /mnt
mount $PARTITION_1 /mnt
cp -avr ./$ROOT_DIR/* /mnt
umount $PARTITION_1

sync
partprobe

echo -e "\nInfo: Process finished\n"

exit 0
