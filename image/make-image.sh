#! /bin/bash -exu

. ./utilities.sh

ROOT_UID="0"

# Check if running as root
if [ "$(id -u)" -ne "$ROOT_UID" ]
then
    report_error "You must be root to execute the script"
    exit 1
fi

BASE_DIR=`pwd`
CONFIG_DIR="$BASE_DIR/config"

. $CONFIG_DIR/common.conf

# Getting the image configuration variables
if [ "$#" -ne 1 ]; then
    report_error "Too many or too few parameters (provide image configuration name)"
    exit 1
fi

CONFIG_NAME=$1
. $CONFIG_DIR/image.conf

# Checking U-Boot
if [ ! -e $UBOOT_IMAGE_FILE ]
then
    report_error "Please build U-Boot first"
    exit 1
fi

# Checking kernel and boot script
if [ ! -e $KERNEL_IMAGE_FILE ]
then
    report_error "Please build the kernel first"
    exit 1
fi

if [ ! -e $SCRIPT_BIN_FILE ]
then
    report_error "No boot script found"
    exit 1
fi

# Checking kernel modules
if [ ! -d $KERNEL_SRC_DIR/$KERNEL_MOD_DIR_NAME ]
then
    report_error "Build kernel modules first"
    exit 1
fi

# Checking multistrap config
if [ ! -e $MULTISTRAP_CONFIG_FILE ]
then
    report_error "Multistrap config not found"
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
if [ -d $OUTPUT_DIR ]
then
    rm -rf $OUTPUT_DIR/*
else
    mkdir -p $OUTPUT_DIR
fi

# Checking stray /proc mount on root-fs directory
set +e
report_info "Checking stray /proc mount on root-fs directory"
if [ -d $ROOTFS_DIR/proc ]
then
    umount $ROOTFS_DIR/proc > /dev/null
fi
set -e

# Cleaning up root-fs directory
report_info "Cleaning up root-fs directory"
if [ -d $ROOTFS_DIR ]
then
    rm -rf $ROOTFS_DIR/*
else
    mkdir -p $ROOTFS_DIR
fi

# Starting multistrap
report_info "Starting multistrap"
multistrap -d $ROOTFS_DIR -f $MULTISTRAP_CONFIG_FILE

# Copying qemu-arm-static to root-fs
report_info "Copying qemu-arm-static to root-fs"
cp $QEMU_BIN $ROOTFS_DIR/usr/bin/

# Configuring the generated root-fs
report_info "Configuring the generated root-fs"
chroot $ROOTFS_DIR<<EOF
export LC_ALL=C LANGUAGE=C LANG=C
echo "nameserver 8.8.8.8" > /etc/resolv.conf
rm -rf /var/lib/apt/lists
wget http://archive.raspbian.org/raspbian.public.key -O - | apt-key add -
wget http://archive.raspberrypi.org/debian/raspberrypi.gpg.key -O - | apt-key add -
umount /proc
mount -t proc proc /proc
/var/lib/dpkg/info/dash.preinst install
echo "dash dash/sh boolean false" | debconf-set-selections
dpkg --configure -a
umount /proc
EOF

# Applying console settings
report_info "Applying console settings"
chroot $ROOTFS_DIR<<EOF
export LC_ALL=C LANGUAGE=C LANG=C
setupcon
EOF

# Copying kernel modules to root-fs
report_info "Copying kernel modules to root-fs"
rsync -arp $KERNEL_SRC_DIR/$KERNEL_MOD_DIR_NAME/lib/modules $ROOTFS_DIR/lib/
rsync -arp $KERNEL_SRC_DIR/$KERNEL_MOD_DIR_NAME/lib/firmware $ROOTFS_DIR/lib/

# Patching the root-fs
report_info "Patching the root-fs"
rsync -arp $PATCHES_DIR/root-fs/common/ $ROOTFS_DIR/
rsync -arp $PATCHES_DIR/root-fs/$1/ $ROOTFS_DIR/

# Setting up memory information tool
echo -e "\nInfo: Setting up memory information tool\n"
chmod 777 $ROOTFS_DIR/usr/bin/a10-meminfo-static

# Installing brickd
report_info "Installing brickd"
chroot $ROOTFS_DIR<<EOF
export LC_ALL=C LANGUAGE=C LANG=C
cd /tmp
wget http://download.tinkerforge.com/tools/brickd/linux/brickd_linux_latest_armhf.deb
dpkg -i brickd_linux_latest_armhf.deb
dpkg --configure -a
EOF

# Installing Node.JS and NPM
report_info "Installing Node.JS and NPM"
chroot $ROOTFS_DIR<<EOF
export LC_ALL=C LANGUAGE=C LANG=C
cd /tmp
dpkg -i node_*
dpkg --configure -a
EOF

# Setting up CPAN
report_info "Setting up CPANminus"
chroot $ROOTFS_DIR<<EOF
export LC_ALL=C LANGUAGE=C LANG=C
rm -rf /root/.cpanm/
cpanm -n Thread::Queue
EOF

# Setting up all the bindings
report_info "Setting up all the bindings"
chroot $ROOTFS_DIR<<EOF
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
rm -rf *_bindings_latest.zip
EOF

# Enable BASH completion
report_info "Enabling BASH completion"
chroot $ROOTFS_DIR<<EOF
export LC_ALL=C LANGUAGE=C LANG=C
. /etc/bash_completion
EOF

# Setting root password
report_info "Setting root password"
chroot $ROOTFS_DIR<<EOF
export LC_ALL=C LANGUAGE=C LANG=C
passwd root
tinkerforge
tinkerforge
EOF

# Adding new user
report_info "Info: Adding new user"
chroot $ROOTFS_DIR<<EOF
export LC_ALL=C LANGUAGE=C LANG=C
adduser rbuser
tinkerforge
tinkerforge
RED Brick User




Y
EOF

# Adding new user to proper groups
report_info "Info: Adding new user to proper groups"
chroot $ROOTFS_DIR<<EOF
usermod -a -G adm rbuser
usermod -a -G dialout rbuser
usermod -a -G cdrom rbuser
usermod -a -G sudo rbuser
usermod -a -G audio rbuser
usermod -a -G video rbuser
usermod -a -G plugdev rbuser
usermod -a -G games rbuser
usermod -a -G users rbuser
usermod -a -G ntp rbuser
usermod -a -G crontab rbuser
usermod -a -G netdev rbuser
EOF

# Add image specific tasks

# Specific tasks for the full image
if [ $1 -eq "full" ]
then
    report_info "Image specific tasks"
    # Configuring Mali GPU
    report_info "Configuring Mali GPU"
    chroot $ROOTFS_DIR<<EOF
    export LC_ALL=C LANGUAGE=C LANG=C
    cd /tmp/mali-gpu
    dpkg -i ./libdri2-1_1.0-2_armhf.deb
    dpkg -i ./libsunxi-mali-x11_1.0-4_armhf.deb
    dpkg -i ./libvdpau-sunxi_1.0-1_armhf.deb
    dpkg -i ./libvpx0_0.9.7.p1-2_armhf.deb
    dpkg -i ./sunxi-disp-test_1.0-1_armhf.deb
    dpkg -i ./udevil_0.4.1-3_armhf.deb
    dpkg -i ./xserver-xorg-video-sunximali_1.0-3_armhf.deb
    dpkg --configure -a
EOF
    # Configuring boot splash image
    report_info "Configuring boot splash image"
    chroot $ROOTFS_DIR<<EOF
    export LC_ALL=C LANGUAGE=C LANG=C
    chmod a+x /etc/init.d/asplashscreen
    chmod a+x /etc/init.d/killasplashscreen
    insserv /etc/init.d/asplashscreen
    insserv /etc/init.d/killasplashscreen
EOF
    # Setting up XDM logo and desktop wallpaper
    report_info "Setting up XDM logo and desktop wallpaper"
    chroot $ROOTFS_DIR<<EOF
    rm -rf /etc/alternatives/desktop-background
    ln -s /usr/share/images/tf-image.png /etc/alternatives/desktop-background
EOF
    # Installing brickv
    report_info "Installing brickv"
    chroot $ROOTFS_DIR<<EOF
    export LC_ALL=C LANGUAGE=C LANG=C
    cd /tmp
    wget http://download.tinkerforge.com/tools/brickv/linux/brickv_linux_latest.deb
    dpkg -i brickv_linux_latest.deb
    dpkg --configure -a
EOF
    # Removing plymouth
    report_info "Removing plymouth"
    chroot $ROOTFS_DIR<<EOF
    export LC_ALL=C LANGUAGE=C LANG=C
    apt-get remove plymouth -y
    apt-get purge plymouth -y
    dpkg --configure -a
EOF
fi

# Cleaning /tmp directory
report_info "Emptying /tmp directory"
chroot $ROOTFS_DIR<<EOF
rm -rf /tmp/*
EOF

# Emptying /etc/resolv.conf
report_info "Emptying /etc/resolv.conf"
chroot $ROOTFS_DIR<<EOF
export LC_ALL=C LANGUAGE=C LANG=C
echo "" > /etc/resolv.conf
EOF

# Cleaning, updating and fixing APT
report_info "Cleaning and updating APT"
chroot $ROOTFS_DIR<<EOF
export LC_ALL=C LANGUAGE=C LANG=C
apt-get clean
apt-get update
apt-get -f install
EOF

# Setting up fake-hwclock
report_info "Setting up fake-hwclock"
chroot $ROOTFS_DIR<<EOF
export LC_ALL=C LANGUAGE=C LANG=C
insserv -r /etc/init.d/hwclock.sh
fake-hwclock
EOF

# Removing qemu-arm-static from the root file system
report_info "Removing qemu-arm-static from the root file system"
rm $ROOTFS_DIR$QEMU_BIN

# Ensure host name integrity
report_info "Ensure host name integrity"
hostname -F /etc/hostname

# Creating empty image
report_info "Creating empty image"
dd bs=$IMAGE_DD_BS count=$IMAGE_DD_COUNT if=/dev/zero of=$OUTPUT_DIR/$IMAGE_NAME.img

# Setting up loop device for image
report_info "Setting up loop device for image"
loop_dev=$(losetup -f)
losetup $loop_dev $OUTPUT_DIR/$IMAGE_NAME.img

# Partitioning image
set +e
report_info "Partitioning the image"
fdisk $loop_dev <<EOF
o
n
p
1
20480

w
EOF
set -e

# Setting up loop device for image partition
report_info "Setting up loop device for image partition"
loop_dev_p1=$(losetup -f)
losetup -o $((512*20480)) $loop_dev_p1 $OUTPUT_DIR/$IMAGE_NAME.img

# Formatting image partition
report_info "Formatting image partition"
mkfs.ext3 $loop_dev_p1

# Installing U-Boot, boot script and the kernel to the image
report_info "Installing U-Boot to the image"
dd bs=512 seek=$UBOOT_DD_SEEK if=$UBOOT_IMAGE_FILE of=$loop_dev
report_info "Installing boot script to the image"
dd bs=512 seek=$SCRIPT_DD_SEEK if=$SCRIPT_BIN_FILE of=$loop_dev
report_info "Installing the kernel to the image"
dd bs=512 seek=$KERNEL_DD_SEEK if=$KERNEL_IMAGE_FILE of=$loop_dev

# Copying root-fs to the image
report_info "Copying root-fs to the image"
mkdir -p $MOUNT_DIR
mount $loop_dev_p1 $MOUNT_DIR
rsync -arp $ROOTFS_DIR/ $MOUNT_DIR
umount $loop_dev_p1

# Releasing loop device
report_info "Releasing loop device"
losetup -d $loop_dev
losetup -d $loop_dev_p1

chown -R `logname`:`logname` $BUILD_DIR

report_info "Process finished"

exit 0
