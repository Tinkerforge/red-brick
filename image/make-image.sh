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
if [ ! -e $1 ]; then
    echo -e "\nError: No such configuration file\n"
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
echo -e "\nInfo: Cleaning up output directory\n"
if [ -d ./$OUTPUT_DIR ]
then
    rm -vrf ./$OUTPUT_DIR
    mkdir   ./$OUTPUT_DIR
else
    mkdir ./$OUTPUT_DIR
fi

# Cleaning up root-fs directory
echo -e "\nInfo: Cleaning up root-fs directory\n"
if [ -d ./$ROOT_DIR ]
then
    rm -vrf ./$ROOT_DIR
fi

# Starting multistrap
echo -e "\nInfo: Starting multistrap\n"
multistrap -f ./$OPTS_DIR/root-fs/$MULTISTRAP_SCRIPT

# Copying qemu-arm-static to root-fs
echo -e "\nInfo: Copying qemu-arm-static to root-fs\n"
cp $QEMU_BIN ./$ROOT_DIR/usr/bin/

# Copying config files to root-fs
echo -e "\nInfo: Copying config files to root-fs\n"
cp ./$OPTS_DIR/root-fs/securetty        ./$ROOT_DIR/etc/
cp ./$OPTS_DIR/root-fs/inittab          ./$ROOT_DIR/etc/
cp ./$OPTS_DIR/root-fs/hostname        ./$ROOT_DIR/etc/
cp ./$OPTS_DIR/root-fs/fstab            ./$ROOT_DIR/etc/
cp ./$OPTS_DIR/root-fs/modules          ./$ROOT_DIR/etc/
cp ./$OPTS_DIR/root-fs/passwd          ./$ROOT_DIR/etc/
cp ./$OPTS_DIR/root-fs/interfaces       ./$ROOT_DIR/etc/network/
cp ./$OPTS_DIR/root-fs/50-mali.rules    ./$ROOT_DIR/etc/udev/rules.d/

# Configuring the generated root-fs
echo -e "\nInfo: Configuring the generated root-fs\n"
chroot ./$ROOT_DIR<<EOF
export LC_ALL=C LANGUAGE=C LANG=C
echo "nameserver 8.8.8.8" > /etc/resolv.conf
wget -qO - http://archive.raspbian.org/raspbian.public.key | sudo apt-key add -
wget -qO - http://archive.raspberrypi.org/debian/raspberrypi.gpg.key | sudo apt-key add -
apt-get update
umount /proc
mount -t proc proc /proc
/var/lib/dpkg/info/dash.preinst install
dpkg --configure -a
sync
umount /proc
EOF

# Copying kernel modules to root-fs
echo -e "\nInfo: Copying kernel modules to root-fs\n"
cp -avr ./$KERNEL_SRC_DIR/$KERNEL_MOD_DIR/lib/modules/ ./$ROOT_DIR/lib/
cp -avr ./$KERNEL_SRC_DIR/$KERNEL_MOD_DIR/lib/firmware/* ./$ROOT_DIR/lib/firmware/

# Configuring boot splash image
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

# Configuring Mali GPU
echo -e "\nInfo: Configuring Mali GPU\n"
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
cd ..
rm -vrf mali-gpu
dpkg --configure -a
apt-get update -y
sync
EOF

# Setting up XDM logo and desktop wallpaper
echo -e "\nInfo: Setting up XDM logo and desktop wallpaper\n"
cp -avr ./$OPTS_DIR/root-fs/tf.xpm ./$ROOT_DIR/usr/share/X11/xdm/pixmaps/
cp -avr ./$OPTS_DIR/root-fs/tf-bw.xpm ./$ROOT_DIR/usr/share/X11/xdm/pixmaps/
cp -avr ./$OPTS_DIR/root-fs/Xresources ./$ROOT_DIR/etc/X11/xdm/
cp -avr ./$OPTS_DIR/root-fs/pcmanfm.conf ./$ROOT_DIR/etc/xdg/pcmanfm/LXDE/
chroot ./$ROOT_DIR<<EOF
rm -vrf /etc/alternatives/desktop-background
ln -s /etc/tf-logo.png /etc/alternatives/desktop-background
sync
EOF

# Installing Node.JS and NPM
echo -e "\nInfo: Installing Node.JS and NPM\n"
cp ./$OPTS_DIR/root-fs/node_0.10.26-1_armhf.deb      ./$ROOT_DIR/tmp/
chroot ./$ROOT_DIR<<EOF
export LC_ALL=C LANGUAGE=C LANG=C
cd /tmp
dpkg -i node_*
rm -vrf ./node_*
dpkg --configure -a
apt-get update -y
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
echo -e "\nInfo: Applying console settings\n"
chroot ./$ROOT_DIR<<EOF
export LC_ALL=C LANGUAGE=C LANG=C
setupcon
sync
EOF

# Setting root password
echo -e "\nInfo: Setting root password\n"
chroot ./$ROOT_DIR<<EOF
export LC_ALL=C LANGUAGE=C LANG=C
passwd root
tf
tf
sync
EOF

# Enable BASH completion
echo -e "\nInfo: Enabling BASH completion\n"
chroot ./$ROOT_DIR<<EOF
export LC_ALL=C LANGUAGE=C LANG=C
. /etc/bash_completion
sync
EOF

# Removing plymouth
echo -e "\nInfo: Removing plymouth\n"
chroot ./$ROOT_DIR<<EOF
export LC_ALL=C LANGUAGE=C LANG=C
apt-get remove plymouth -y
apt-get purge plymouth -y
dpkg --configure -a
apt-get update -y
sync
EOF

# Installing brickv and brickd
echo -e "\nInfo: Installing brickv and brickd\n"
chroot ./$ROOT_DIR<<EOF
export LC_ALL=C LANGUAGE=C LANG=C
cd /tmp
wget http://download.tinkerforge.com/tools/brickd/linux/brickd_linux_latest_armhf.deb
wget http://download.tinkerforge.com/tools/brickv/linux/brickv_linux_latest.deb
dpkg -i brickd_linux_latest_armhf.deb
dpkg -i brickv_linux_latest.deb
apt-get -f install -y
dpkg --configure -a
apt-get update -y
rm -vrf brickv_linux_latest*
sync
EOF

# Cleaning and updating APT
echo -e "\nInfo: Cleaning and updating APT\n"
chroot ./$ROOT_DIR<<EOF
export LC_ALL=C LANGUAGE=C LANG=C
apt-get clean
apt-get update
sync
EOF

# Emptying /etc/resolv.conf
echo -e "\nInfo: Emptying /etc/resolv.conf\n"
chroot ./$ROOT_DIR<<EOF
export LC_ALL=C LANGUAGE=C LANG=C
echo "" > /etc/resolv.conf
sync
EOF

# Copying /etc/issue and /etc/os-release
echo -e "\nInfo: Copying /etc/issue and /etc/os-release\n"
cp ./$OPTS_DIR/root-fs/issue            ./$ROOT_DIR/etc/
cp ./$OPTS_DIR/root-fs/os-release       ./$ROOT_DIR/etc/

# Setting up fake-hwclock
echo -e "\nInfo: Setting up fake-hwclock\n"
chroot ./$ROOT_DIR<<EOF
export LC_ALL=C LANGUAGE=C LANG=C
insserv -r /etc/init.d/hwclock.sh
fake-hwclock
sync
EOF

# Removing qemu-arm-static from the root file system
echo -e "\nInfo: Removing qemu-arm-static from the root file system\n"
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
echo -e "\nInfo: Formatting image partition\n"
mkfs.ext3 $loop_dev_p1

# Installing U-Boot, boot script and the kernel to the image
echo -e "\nInfo: Installing U-Boot to the image\n"
dd bs=512 seek=$UBOOT_DD_SEEK if=./$UBOOT_SRC_DIR/spl/$UBOOT_IMAGE of=$loop_dev
echo -e "\nInfo: Installing boot script to the image\n"
dd bs=512 seek=$SCRIPTBIN_DD_SEEK if=./$OPTS_DIR/kernel/$KERNEL_SCRIPT_BIN of=$loop_dev
echo -e "\nInfo: Installing the kernel to the image\n"
dd bs=512 seek=$KERNEL_DD_SEEK if=./$KERNEL_SRC_DIR/arch/arm/boot/$KERNEL_IMAGE of=$loop_dev

# Copying root-fs to the image
echo -e "\nInfo: Copying root-fs to the image\n"
umount /mnt
mount $loop_dev_p1 /mnt
cp -avr ./$ROOT_DIR/* /mnt
sync
umount $loop_dev_p1

# Releasing loop device
echo -e "\nInfo: Releasing loop device\n"
losetup -d $loop_dev
losetup -d $loop_dev_p1

sync

echo -e "\nInfo: Process finished\n"

exit 0

