#!/bin/bash

set -ex

. ./utilities.sh

ROOT_UID="0"

# Check if running as root
if [ "$UID" -ne "$ROOT_UID" ]
then
    report_error "You must be root to execute the script"
    exit 1
fi

# Getting the configuration variables
if [ "$#" -ne 1 ]; then
    report_error "Too many or too few parameters (provide image configuration)"
    exit 1
fi
if [ ! -e $1 ] || [ -d $1 ]; then
    report_error "No such configuration file"
    exit 1
fi
. $1

# Checking U-Boot
if [ ! -e ./$UBOOT_SRC_DIR/spl/$UBOOT_IMAGE ]
then
    report_error "Please build U-Boot first"
    exit 1
fi

# Checking kernel and boot script
if [ ! -e ./$KERNEL_SRC_DIR/arch/arm/boot/$KERNEL_IMAGE ]
then
    report_error "Please build the kernel first"
    exit 1
fi
if [ ! -e ./$OPTS_DIR/kernel/$KERNEL_SCRIPT_BIN ]
then
    report_error "No boot script found"
    exit 1
fi

# Checking kernel modules
if [ ! -d ./$KERNEL_SRC_DIR/$KERNEL_MOD_DIR ]
then
    report_error "Build kernel modules first"
    exit 1
fi

# Checking multistrap script
if [ ! -e ./$OPTS_DIR/root-fs/$MULTISTRAP_SCRIPT ]
then
    report_error "Multistrap script not found"
    exit 1
fi

# Checking qemu support
if [ ! -e $QEMU_BIN ]
then
    report_error "Install qemu support for ARM"
    exit 1
fi

# Cleaning up output directory
report_info "Cleaning up output directory"
if [ -d ./$OUTPUT_DIR ]
then
    rm -vrf ./$OUTPUT_DIR
    mkdir ./$OUTPUT_DIR
else
    mkdir ./$OUTPUT_DIR
fi

# Cleaning up root-fs directory
report_info "Cleaning up root-fs directory"
if [ -d ./$ROOT_DIR ]
then
    rm -vrf ./$ROOT_DIR
fi

# Cleaning up the mount directory
if [ -d ./$MOUNT_DIR ]
then
    report_info "Cleaning up the mount directory"
    rm -vrf ./$MOUNT_DIR
    exit 1
fi

# Starting multistrap
report_info "Starting multistrap"
multistrap -f ./$OPTS_DIR/root-fs/$MULTISTRAP_SCRIPT

# Copying qemu-arm-static to root-fs
report_info "Copying qemu-arm-static to root-fs"
cp $QEMU_BIN ./$ROOT_DIR/usr/bin/

# Copying config files to root-fs
report_info "Copying config files to root-fs"
cp ./$OPTS_DIR/root-fs/securetty        ./$ROOT_DIR/etc/
cp ./$OPTS_DIR/root-fs/inittab          ./$ROOT_DIR/etc/
cp ./$OPTS_DIR/root-fs/hostname        ./$ROOT_DIR/etc/
cp ./$OPTS_DIR/root-fs/fstab            ./$ROOT_DIR/etc/
cp ./$OPTS_DIR/root-fs/modules          ./$ROOT_DIR/etc/
cp ./$OPTS_DIR/root-fs/passwd          ./$ROOT_DIR/etc/
cp ./$OPTS_DIR/root-fs/interfaces       ./$ROOT_DIR/etc/network/
cp ./$OPTS_DIR/root-fs/50-mali.rules    ./$ROOT_DIR/etc/udev/rules.d/
cp ./$OPTS_DIR/root-fs/.octaverc        ./$ROOT_DIR/root/

# Configuring the generated root-fs
report_info "Configuring the generated root-fs"
chroot ./$ROOT_DIR<<EOF
export LC_ALL=C LANGUAGE=C LANG=C
echo "nameserver 8.8.8.8" > /etc/resolv.conf
rm -vrf /var/lib/apt/lists
apt-get clean
wget http://archive.raspbian.org/raspbian.public.key -O - | apt-key add -
wget http://archive.raspberrypi.org/debian/raspberrypi.gpg.key -O - | apt-key add -
apt-get update
umount /proc
mount -t proc proc /proc
/var/lib/dpkg/info/dash.preinst install
dpkg --configure -a
sync
umount /proc
EOF

# Copying kernel modules to root-fs
report_info "Copying kernel modules to root-fs"
cp -avr ./$KERNEL_SRC_DIR/$KERNEL_MOD_DIR/lib/modules/ ./$ROOT_DIR/lib/
cp -avr ./$KERNEL_SRC_DIR/$KERNEL_MOD_DIR/lib/firmware/* ./$ROOT_DIR/lib/firmware/

# Configuring boot splash image
report_info "Configuring boot splash image"
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
report_info "Configuring Mali GPU"
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
report_info "Setting up XDM logo and desktop wallpaper"
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
report_info "Installing Node.JS and NPM"
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
report_info "Applying console settings"
chroot ./$ROOT_DIR<<EOF
export LC_ALL=C LANGUAGE=C LANG=C
setupcon
sync
EOF

# Setting root password
report_info "Setting root password"
chroot ./$ROOT_DIR<<EOF
export LC_ALL=C LANGUAGE=C LANG=C
passwd root
tf
tf
sync
EOF

# Enable BASH completion
report_info "Enabling BASH completion"
chroot ./$ROOT_DIR<<EOF
export LC_ALL=C LANGUAGE=C LANG=C
. /etc/bash_completion
sync
EOF

# Removing plymouth
report_info "Removing plymouth"
chroot ./$ROOT_DIR<<EOF
export LC_ALL=C LANGUAGE=C LANG=C
apt-get remove plymouth -y
apt-get purge plymouth -y
dpkg --configure -a
apt-get update -y
sync
EOF

# Installing brickv and brickd
report_info "Installing brickv and brickd"
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

# Setting up CPAN
report_info "Setting up CPAN"
chroot ./$ROOT_DIR<<EOF
export LC_ALL=C LANGUAGE=C LANG=C
cpan upgrade Thread::Queue


sync
EOF

# Setting up all the bindings
report_info "Setting up all the bindings"
chroot ./$ROOT_DIR<<EOF
export LC_ALL=C LANGUAGE=C LANG=C
mkdir -p /usr/tinkerforge/bindings
cd /usr/tinkerforge/bindings
wget http://download.tinkerforge.com/bindings/c/tinkerforge_c_bindings_latest.zip
unzip -d c_c++ tinkerforge_c_bindings_latest.zip
wget http://download.tinkerforge.com/bindings/csharp/tinkerforge_csharp_bindings_latest.zip
unzip -d c# tinkerforge_csharp_bindings_latest.zip
wget http://download.tinkerforge.com/bindings/delphi/tinkerforge_delphi_bindings_latest.zip
unzip -d delphi tinkerforge_delphi_bindings_latest.zip
wget http://download.tinkerforge.com/bindings/java/tinkerforge_java_bindings_latest.zip
unzip -d java tinkerforge_java_bindings_latest.zip
wget http://download.tinkerforge.com/bindings/javascript/tinkerforge_javascript_bindings_latest.zip
unzip -d javascript tinkerforge_javascript_bindings_latest.zip
wget http://download.tinkerforge.com/bindings/labview/tinkerforge_labview_bindings_latest.zip
unzip -d labview tinkerforge_labview_bindings_latest.zip
wget http://download.tinkerforge.com/bindings/mathematica/tinkerforge_mathematica_bindings_latest.zip
unzip -d mathematica tinkerforge_mathematica_bindings_latest.zip
wget http://download.tinkerforge.com/bindings/matlab/tinkerforge_matlab_bindings_latest.zip
unzip -d matlab tinkerforge_matlab_bindings_latest.zip
wget http://download.tinkerforge.com/bindings/perl/tinkerforge_perl_bindings_latest.zip
unzip -d perl tinkerforge_perl_bindings_latest.zip
cd perl
tar zxvf Tinkerforge.tar.gz
cd Tinkerforge-*
perl Makefile.PL
make all
make install
make test
cd /usr/tinkerforge/bindings
wget http://download.tinkerforge.com/bindings/php/tinkerforge_php_bindings_latest.zip
unzip -d php tinkerforge_php_bindings_latest.zip
cd php
pear install Tinkerforge.tgz
cd /usr/tinkerforge/bindings
wget http://download.tinkerforge.com/bindings/python/tinkerforge_python_bindings_latest.zip
unzip -d python tinkerforge_python_bindings_latest.zip
cd python
easy_install tinkerforge.egg
cd /usr/tinkerforge/bindings
wget http://download.tinkerforge.com/bindings/ruby/tinkerforge_ruby_bindings_latest.zip
unzip -d ruby tinkerforge_ruby_bindings_latest.zip
cd ruby
gem install tinkerforge.gem
cd /usr/tinkerforge/bindings
wget http://download.tinkerforge.com/bindings/shell/tinkerforge_shell_bindings_latest.zip
unzip -d shell tinkerforge_shell_bindings_latest.zip
cd shell
cp ./tinkerforge /usr/local/bin/
cp tinkerforge-bash-completion.sh /etc/bash_completion.d/
. /etc/bash_completion
cd /usr/tinkerforge/bindings
wget http://download.tinkerforge.com/bindings/vbnet/tinkerforge_vbnet_bindings_latest.zip
unzip -d vbnet tinkerforge_vbnet_bindings_latest.zip
cd /usr/tinkerforge/bindings
rm -vrf *_bindings_latest.zip
sync
EOF

# Cleaning and updating APT
report_info "Cleaning and updating APT"
chroot ./$ROOT_DIR<<EOF
export LC_ALL=C LANGUAGE=C LANG=C
apt-get clean
apt-get update
sync
EOF

# Emptying /etc/resolv.conf
report_info "Emptying /etc/resolv.conf"
chroot ./$ROOT_DIR<<EOF
export LC_ALL=C LANGUAGE=C LANG=C
echo "" > /etc/resolv.conf
sync
EOF

# Copying /etc/issue and /etc/os-release
report_info "Copying /etc/issue and /etc/os-release"
cp ./$OPTS_DIR/root-fs/issue ./$ROOT_DIR/etc/
cp ./$OPTS_DIR/root-fs/os-release ./$ROOT_DIR/etc/

# Setting up fake-hwclock
report_info "Setting up fake-hwclock"
chroot ./$ROOT_DIR<<EOF
export LC_ALL=C LANGUAGE=C LANG=C
insserv -r /etc/init.d/hwclock.sh
fake-hwclock
sync
EOF

# Removing qemu-arm-static from the root file system
report_info "Removing qemu-arm-static from the root file system"
rm ./$ROOT_DIR$QEMU_BIN

# Creating empty image
report_info "Creating empty image"
dd bs=$IMAGE_BS count=$IMAGE_COUNT if=/dev/zero of=./$OUTPUT_DIR/$IMAGE_NAME.img

# Setting up loop device for image
report_info "Setting up loop device for image"
loop_dev=$(losetup -f)
losetup $loop_dev ./$OUTPUT_DIR/$IMAGE_NAME.img

# Partitioning image
report_info "Partitioning the image"
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
report_info "Setting up loop device for image partition"
loop_dev_p1=$(losetup -f)
losetup -o $((512*20480)) $loop_dev_p1 ./$OUTPUT_DIR/$IMAGE_NAME.img

# Formatting image partition
report_info "Formatting image partition"
mkfs.ext3 $loop_dev_p1

# Installing U-Boot, boot script and the kernel to the image
report_info "Installing U-Boot to the image"
dd bs=512 seek=$UBOOT_DD_SEEK if=./$UBOOT_SRC_DIR/spl/$UBOOT_IMAGE of=$loop_dev
report_info "Installing boot script to the image"
dd bs=512 seek=$SCRIPTBIN_DD_SEEK if=./$OPTS_DIR/kernel/$KERNEL_SCRIPT_BIN of=$loop_dev
report_info "Installing the kernel to the image"
dd bs=512 seek=$KERNEL_DD_SEEK if=./$KERNEL_SRC_DIR/arch/arm/boot/$KERNEL_IMAGE of=$loop_dev

# Copying root-fs to the image
report_info "Copying root-fs to the image"
rm -vrf ./$MOUNT_DIR
mkdir ./$MOUNT_DIR
mount $loop_dev_p1 ./$MOUNT_DIR
cp -avr ./$ROOT_DIR/* ./$MOUNT_DIR
sync
umount $loop_dev_p1
rm -vrf ./$MOUNT_DIR

# Releasing loop device
report_info "Releasing loop device"
losetup -d $loop_dev
losetup -d $loop_dev_p1

sync

report_info "Process finished"

exit 0
