#!/bin/bash -exu

# RED Brick Image Generator
# Copyright (C) 2014-2015 Matthias Bolte <matthias@tinkerforge.com>
# Copyright (C) 2014-2017 Ishraq Ibne Ashraf <ishraq@tinkerforge.com>
# Copyright (C) 2014-2015 Olaf Lüke <olaf@tinkerforge.com>
#
# make-root-fs.sh: Makes the root-fs for the images
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public
# License along with this program; if not, write to the
# Free Software Foundation, Inc., 59 Temple Place - Suite 330,
# Boston, MA 02111-1307, USA.

. ./utilities.sh

ensure_running_as_root

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

# Adding the toolchain to the subshell environment
export PATH=$TOOLS_DIR/$TC_DIR_NAME/bin:$PATH

# Some helper variables and functions
function unmount {
	report_info "Unmounting /proc, /sys and /dev from the root-fs directory"

	set +e

	if [ -d $ROOTFS_DIR/proc ]
	then
		umount -f $ROOTFS_DIR/proc
	fi

	if [ -d $ROOTFS_DIR/sys ]
	then
		umount -f $ROOTFS_DIR/sys
	fi

	if [ -e $ROOTFS_DIR/dev/pts ]
	then
		umount -f $ROOTFS_DIR/dev/pts
	fi

	if [ -e $ROOTFS_DIR/dev ]
	then
		umount -f $ROOTFS_DIR/dev
	fi

	set -e
}

# Cleanup function in case of interrupts
function cleanup {
	report_info "Cleaning up before exit..."

	unmount

	# Ensure host name integrity
	hostname -F /etc/hostname
}

trap "cleanup" SIGHUP SIGINT SIGTERM SIGQUIT EXIT

# Checking if the kernel and U-Boot were compiled for current configuration
if [ ! -e $BUILD_DIR/u-boot-$CONFIG_NAME.built ]
then
	report_error "U-Boot was not built for the current image configuration"
	exit 1
fi

if [ ! -e $BUILD_DIR/kernel-$CONFIG_NAME.built ]
then
	report_error "Kernel was not built for the current image configuration"
	exit 1
fi

# Get kernel release
pushd $KERNEL_SRC_DIR > /dev/null
KERNEL_RELEASE=`make -s \
ARCH=arm \
CROSS_COMPILE=$TC_PREFIX \
LOCALVERSION="" \
kernelrelease`

# Change root command
CHROOT="taskset 0x01 env -i \
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
LANG=$LOCALE \
LANGUAGE=$LANGUAGE \
LC_ALL=$LOCALE \
DEBIAN_FRONTEND=noninteractive \
DEBCONF_NONINTERACTIVE_SEEN=true \
KERNEL_RELEASE=$KERNEL_RELEASE \
chroot $ROOTFS_DIR /bin/bash"

# Checking multistrap config
if [ ! -e $MULTISTRAP_TEMPLATE_FILE ]
then
	report_error "Multistrap config not found"
	exit 1
fi

# Unmounting stray mounts from the root-fs
unmount

# Cleaning up root-fs directory
report_info "Cleaning up root-fs directory"
if [ -d $ROOTFS_DIR ]
then
	rm -rf $ROOTFS_DIR
fi

mkdir -p $ROOTFS_DIR

# Mounting critical filesystems on root-fs
report_info "Mounting critical filesystems on root-fs"
mkdir -p $ROOTFS_DIR/proc
mount -t proc proc $ROOTFS_DIR/proc
mkdir -p $ROOTFS_DIR/sys
mount -t sysfs sysfs $ROOTFS_DIR/sys
mkdir -p $ROOTFS_DIR/dev
mount -o bind /dev $ROOTFS_DIR/dev
mkdir -p $ROOTFS_DIR/dev/pts
mount -o bind /dev/pts $ROOTFS_DIR/dev/pts

# Starting multistrap
aptcacher=`netstat -lnt | awk '$6 == "LISTEN" && $4 ~ ".3150"'`

if [ -n "$aptcacher" ]
then
	report_info "Starting multistrap, using apt-cacher"
	sed -e 's/%apt-cacher-\([0-9]\+\)-prefix%/'`hostname`':315\1\//' $MULTISTRAP_TEMPLATE_FILE > $MULTISTRAP_CONFIG_FILE
else
	report_info "Starting multistrap"
	sed -e 's/%apt-cacher-\([0-9]\+\)-prefix%//' $MULTISTRAP_TEMPLATE_FILE > $MULTISTRAP_CONFIG_FILE
fi

multistrap -d $ROOTFS_DIR -f $MULTISTRAP_CONFIG_FILE

# Patching the root-fs
report_info "Patching the root-fs"
rsync -ac --no-o --no-g $PATCHES_DIR/root-fs/common/ $ROOTFS_DIR/
rsync -ac --no-o --no-g $PATCHES_DIR/root-fs/$CONFIG_NAME/ $ROOTFS_DIR/

# Write /etc/tf_image_version
report_info "Write /etc/tf_image_version"
echo "${IMAGE_DOT_VERSION} (${CONFIG_NAME})" > $ROOTFS_DIR/etc/tf_image_version

# Create /tmp and set correct mode
mkdir -p $ROOTFS_DIR/tmp
chmod 1777 $ROOTFS_DIR/tmp

# Disable starting daemons in the chroot
report_info "Disable starting daemons in the chroot"
cat > $ROOTFS_DIR/usr/sbin/policy-rc.d <<EOF
#!/bin/bash
exit 101
EOF
chmod a+x $ROOTFS_DIR/usr/sbin/policy-rc.d

# Copying qemu-arm-static to root-fs
report_info "Copying qemu-arm-static to root-fs"
if ! [[ "$QEMU_MIN_VER_NO_BUILD" = "`/bin/echo -e "$QEMU_CUR_VER\n$QEMU_MIN_VER_NO_BUILD" | /usr/bin/sort -V | /usr/bin/head -n1`" ]];
then
	cp $TOOLS_DIR/$QEMU_BASE_NAME/arm-linux-user/qemu-arm $ROOTFS_DIR$QEMU_BIN
else
	cp /usr/bin/qemu-arm $ROOTFS_DIR$QEMU_BIN
fi

# Configuring the generated root-fs
report_info "Configuring the generated root-fs"
# FIXME: using host resolv.conf might not be the right thing to do here
cp /etc/resolv.conf $ROOTFS_DIR/etc/resolv.conf
$CHROOT <<EOF
echo $LOCALE_CHARSET > /etc/locale.gen
locale-gen
update-locale LANG=$LOCALE LANGUAGE=$LANGUAGE LC_ALL=$LOCALE
/var/lib/dpkg/info/dash.preinst install
echo "dash dash/sh boolean false" | debconf-set-selections
echo "tzdata tzdata/Areas select $TZDATA_AREA" | debconf-set-selections
echo "tzdata tzdata/Zones/Europe select $TZDATA_ZONE" | debconf-set-selections
echo '# KEYBOARD CONFIGURATION FILE

# Consult the keyboard(5) manual page.

XKBMODEL="$KB_MODEL"
XKBLAYOUT="$KB_LAYOUT"
XKBVARIANT="$KB_VARIANT"
XKBOPTIONS="$KB_OPTIONS"

BACKSPACE="$KB_BACKSPACE"
' > /etc/default/keyboard
setupcon
dpkg --configure -a
# Add true here to avoid having a dpkg error abort the whole script here
true
EOF

# Adding new user
report_info "Adding new user"
$CHROOT <<EOF
rm -rf /home/
mkdir /home/
useradd -m -c "RED Brick User" -G adm,dialout,cdrom,sudo,audio,video,plugdev,games,users,ntp,crontab,netdev tf
echo tf:tf | chpasswd
EOF

# Installing the kernel and preparing the boot directory
report_info "Installing the kernel and preparing the boot directory"
pushd $SOURCE_DIR > /dev/null

if [ ! -f linux-$KERNEL_RELEASE.tar.gz ]; then
	mv *.orig.tar.gz linux-$KERNEL_RELEASE.tar.gz
fi

if [ ! -f linux-firmware-image-$KERNEL_RELEASE.deb ]; then
	mv linux-firmware-image* linux-firmware-image-$KERNEL_RELEASE.deb
fi

if [ ! -f linux-headers-$KERNEL_RELEASE.deb ]; then
	mv linux-headers* linux-headers-$KERNEL_RELEASE.deb
fi

if [ ! -f linux-image-$KERNEL_RELEASE.deb ]; then
	mv linux-image* linux-image-$KERNEL_RELEASE.deb
fi

if [ ! -f linux-libc-dev-$KERNEL_RELEASE.deb ]; then
	mv linux-libc-dev* linux-libc-dev-$KERNEL_RELEASE.deb
fi

if [ ! -f linux-$KERNEL_RELEASE.changes ]; then
	mv *.changes linux-$KERNEL_RELEASE.changes
fi

if [ ! -f linux-$KERNEL_RELEASE.dsc ]; then
	mv *.dsc linux-$KERNEL_RELEASE.dsc
fi

cp linux-$KERNEL_RELEASE.tar.gz $ROOTFS_DIR/usr/src
cp *.deb $ROOTFS_DIR/boot
cp *.changes $ROOTFS_DIR/boot
cp *.dsc $ROOTFS_DIR/boot
mkdir -p $ROOTFS_DIR/boot/dt
cp $KERNEL_DTS_FILE $ROOTFS_DIR/boot/dt
cp $KERNEL_DTB_FILE $ROOTFS_DIR/boot/dt
cp $UBOOT_BOOT_CMD_FILE $ROOTFS_DIR/boot
$UBOOT_SRC_DIR/tools/mkimage -C none -A arm -T script -d $ROOTFS_DIR/boot/boot.cmd $ROOTFS_DIR/boot/boot.scr
$CHROOT <<EOF
cd /boot
dpkg -i linux-firmware-image-$KERNEL_RELEASE.deb
dpkg -i linux-headers-$KERNEL_RELEASE.deb
dpkg -i linux-image-$KERNEL_RELEASE.deb
dpkg -i linux-libc-dev-$KERNEL_RELEASE.deb
apt-mark hold linux-firmware-image-$KERNEL_RELEASE
apt-mark hold linux-headers-$KERNEL_RELEASE
apt-mark hold linux-image-$KERNEL_RELEASE
apt-mark hold linux-libc-dev
EOF

# Enabling ttyGS0 systemd service
report_info "Enabling ttyGS0 systemd service"
$CHROOT <<EOF
systemctl enable serial-getty@ttyGS0.service
EOF

# Enabling tty2 systemd service (used for X server)
report_info "Enabling tty2 systemd service (used for X server)"
$CHROOT <<EOF
systemctl enable getty@tty2.service
EOF

# Fixing JAVA libjvm.so location for Octave bindings
report_info "Fixing JAVA libjvm.so location for Octave bindings"
$CHROOT <<EOF
cd /usr/lib/jvm/java-8-openjdk-armhf/jre/lib/arm
ln -s client server
EOF

# Installing brickd
if [ "$USE_LOCAL_PACKAGES" = "yes" ] && [ -f $BASE_DIR/local_packages/brickd_linux_latest+redbrick_armhf.deb ]
then
	report_info "Installing brickd (using local package)"
	cp $BASE_DIR/local_packages/brickd_linux_latest+redbrick_armhf.deb $ROOTFS_DIR/tmp
else
	report_info "Installing brickd"
	wget -P $ROOTFS_DIR/tmp http://download.tinkerforge.com/tools/brickd/linux/brickd_linux_latest+redbrick_armhf.deb
fi

$CHROOT <<EOF
dpkg -i /tmp/brickd_linux_latest+redbrick_armhf.deb
dpkg --configure -a
systemctl enable brickd.service
# Add true here to avoid having a dpkg error abort the whole script here
true
EOF

# Installing redapid
if [ "$USE_LOCAL_PACKAGES" = "yes" ] && [ -f $BASE_DIR/local_packages/redapid_linux_latest_armhf.deb ]
then
	report_info "Installing redapid (using local package)"
	cp $BASE_DIR/local_packages/redapid_linux_latest_armhf.deb $ROOTFS_DIR/tmp
else
	report_info "Installing redapid"
	wget -P $ROOTFS_DIR/tmp http://download.tinkerforge.com/tools/redapid/linux/redapid_linux_latest_armhf.deb
fi

$CHROOT <<EOF
dpkg -i /tmp/redapid_linux_latest_armhf.deb
dpkg --configure -a
# Add true here to avoid having a dpkg error abort the whole script here
true
EOF

# Installing Node.js and NPM
report_info "Installing Node.js and NPM"
$CHROOT <<EOF
curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash -
apt-get install nodejs -y
cd /usr/local/bin
ln -s /usr/bin/node node
cd /usr/lib
ln -s node_modules node
EOF

# Updating Perl modules
report_info "Updating Perl modules"
$CHROOT <<EOF
rm -rf /root/.cpanm/
# GROUP-START:perl
cpanm install -n Thread::Queue
# GROUP-END:perl
EOF

# Setting up scripts directory (red-brick's brickv mechanism)
report_info "Setting up scripts directory"
$CHROOT <<EOF
mkdir -p /usr/local/scripts
EOF

# Setting up all the bindings
report_info "Setting up all the bindings"
$CHROOT <<EOF
mkdir -p /usr/tinkerforge/bindings
cd /usr/tinkerforge/bindings
wget http://download.tinkerforge.com/bindings/c/tinkerforge_c_bindings_latest.zip
unzip -q -d c tinkerforge_c_bindings_latest.zip
cd c/source/
make
prefix=/usr make install
cd /usr/tinkerforge/bindings
wget http://download.tinkerforge.com/bindings/csharp/tinkerforge_csharp_bindings_latest.zip
unzip -q -d csharp tinkerforge_csharp_bindings_latest.zip
cd csharp/
cp Tinkerforge.dll /usr/lib/
cd /usr/tinkerforge/bindings
wget http://download.tinkerforge.com/bindings/delphi/tinkerforge_delphi_bindings_latest.zip
unzip -q -d delphi tinkerforge_delphi_bindings_latest.zip
cd delphi/source/
export FPCDIR=/usr/lib/fpc/default
fpcmake
make
make install
make clean
rm -rf units
cd /usr/tinkerforge/bindings
wget http://download.tinkerforge.com/bindings/java/tinkerforge_java_bindings_latest.zip
unzip -q -d java tinkerforge_java_bindings_latest.zip
wget http://download.tinkerforge.com/bindings/javascript/tinkerforge_javascript_bindings_latest.zip
unzip -q -d javascript tinkerforge_javascript_bindings_latest.zip
cd javascript/nodejs
npm config set unsafe-perm true
npm install -g ./tinkerforge.tgz
cd /usr/tinkerforge/bindings
wget http://download.tinkerforge.com/bindings/labview/tinkerforge_labview_bindings_latest.zip
unzip -q -d labview tinkerforge_labview_bindings_latest.zip
wget http://download.tinkerforge.com/bindings/mathematica/tinkerforge_mathematica_bindings_latest.zip
unzip -q -d mathematica tinkerforge_mathematica_bindings_latest.zip
wget http://download.tinkerforge.com/bindings/matlab/tinkerforge_matlab_bindings_latest.zip
unzip -q -d matlab tinkerforge_matlab_bindings_latest.zip
wget http://download.tinkerforge.com/bindings/perl/tinkerforge_perl_bindings_latest.zip
unzip -q -d perl tinkerforge_perl_bindings_latest.zip
cd perl/source
perl Makefile.PL
make all
make test
make install
cd /usr/tinkerforge/bindings
wget http://download.tinkerforge.com/bindings/php/tinkerforge_php_bindings_latest.zip
unzip -q -d php tinkerforge_php_bindings_latest.zip
cd php
pear install Tinkerforge.tgz
cd /usr/tinkerforge/bindings
wget http://download.tinkerforge.com/bindings/python/tinkerforge_python_bindings_latest.zip
unzip -q -d python tinkerforge_python_bindings_latest.zip
cd python/source
python2 setup.py install
python3 setup.py install
cd /usr/tinkerforge/bindings
wget http://download.tinkerforge.com/bindings/ruby/tinkerforge_ruby_bindings_latest.zip
unzip -q -d ruby tinkerforge_ruby_bindings_latest.zip
cd ruby
gem install tinkerforge.gem
cd /usr/tinkerforge/bindings
wget http://download.tinkerforge.com/bindings/shell/tinkerforge_shell_bindings_latest.zip
unzip -q -d shell tinkerforge_shell_bindings_latest.zip
cd shell
cp ./tinkerforge /usr/local/bin/
cp tinkerforge-bash-completion.sh /etc/bash_completion.d/
cd /usr/tinkerforge/bindings
wget http://download.tinkerforge.com/bindings/vbnet/tinkerforge_vbnet_bindings_latest.zip
unzip -q -d vbnet tinkerforge_vbnet_bindings_latest.zip
cd /usr/tinkerforge/bindings
rm -rf *_bindings_latest.zip
EOF

# Installing Mono features
report_info "Installing Mono features"
$CHROOT <<EOF
cd /tmp/features/mono_features/
unzip -q ./MathNet.Numerics-3.0.1.zip
unzip -q ./mysql-connector-net-6.8.3-noinstall.zip -d ./mysql-connector-net
unzip -q ./SharpPcap-4.2.0.bin.zip
unzip -q ./itextsharp-all-5.5.1.zip -d ./itextsharp
unzip -q ./xml-rpc.net.2.5.0.zip -d ./xml-rpc.net
cd /tmp/features/mono_features/MathNet.Numerics/Net35
cp ./*.dll /usr/lib/mono/4.0/
cd /tmp/features/mono_features/MathNet.Numerics/Net40
cp ./*.dll /usr/lib/mono/4.0/
cd /tmp/features/mono_features/mysql-connector-net/v2.0/
mv ./mysql.data.cf.dll ./MySql.Data.CF.dll
mv ./mysql.data.dll ./MySql.Data.dll
mv ./mysql.data.entity.dll ./MySql.Data.Entity.dll
mv ./mysql.web.dll ./MySql.Web.dll
cp ./MySql.* /usr/lib/mono/4.0/
cd /tmp/features/mono_features/mysql-connector-net/v4.0/
mv ./mysql.data.dll ./MySql.Data.dll
mv ./mysql.data.entity.dll ./MySql.Data.Entity.dll
mv ./mysql.data.entity.EF6.dll ./MySql.Data.Entity.EF6.dll
mv ./mysql.web.dll ./MySql.Web.dll
cp ./MySql.* /usr/lib/mono/4.0/
cd /tmp/features/mono_features/mysql-connector-net/v4.5/
mv ./mysql.data.dll ./MySql.Data.dll
mv ./mysql.data.entity.EF5.dll ./MySql.Data.Entity.EF5.dll
mv ./mysql.data.entity.EF6.dll ./MySql.Data.Entity.EF6.dll
mv ./mysql.web.dll ./MySql.Web.dll
cp ./MySql.* /usr/lib/mono/4.5/
cd /tmp/features/mono_features/SharpPcap-4.2.0/Release/
cp ./*.dll /usr/lib/mono/4.0/
cp ./*.config /usr/lib/mono/4.0/
cd /tmp/features/mono_features/itextsharp/
cp ./*.dll /usr/lib/mono/4.0/
cd /tmp/features/mono_features/xml-rpc.net/
cp ./*.dll /usr/lib/mono/4.0/
if  [ "$CONFIG_NAME" = "full" ]
then
	cd /tmp/features/mono_features/
	unzip -q opentk-2014-06-20.zip -d ./OpenTK
	cd ./OpenTK/Binaries/OpenTK/Release/
	cp ./*.dll /usr/lib/mono/4.0/
	cp ./*.config /usr/lib/mono/4.0/
fi
EOF

# Installing Java features
report_info "Installing Java features"
$CHROOT <<EOF
cd /tmp/features/java_features/
cp ./*.jar /usr/share/java/
EOF

if [ "$DRAFT_MODE" = "no" ]
then
	# Installing Ruby features
	report_info "Installing Ruby features"
	$CHROOT <<EOF
# GROUP-START:ruby
gem install --no-ri --no-rdoc bundler rake rubocop
gem install --no-ri --no-rdoc mysql2 sqlite3
gem install --no-ri --no-rdoc rubyvis plotrb statsample distribution minimization integration
gem install --no-ri --no-rdoc ruby-pcap curb
gem install --no-ri --no-rdoc msgpack-rpc
gem install --no-ri --no-rdoc prawn god
# GROUP-END:ruby
if [ "$CONFIG_NAME" = "full" ]
then
	# GROUP-START-FULL:ruby
	gem install --no-ri --no-rdoc gtk2 gtk3 opengl
	# GROUP-END-FULL:ruby
fi
EOF
fi

# Installing Python features
report_info "Installing Python features"
$CHROOT <<EOF
# GROUP-START:python
pip install pycrypto
pip install pynag
pip install watchdog
# GROUP-END:python
EOF

# Installing Perl features
report_info "Installing Perl features"
$CHROOT <<EOF
# GROUP-START:perl
cpanm install -n RPC::Simple
# GROUP-END:perl
EOF

# Installing PHP features
report_info "Installing PHP features"
$CHROOT <<EOF
pear config-set preferred_state alpha
pear channel-update pear.php.net
# GROUP-START:php
pear install --onlyreqdeps FSM Archive_Tar Archive_Zip
pear install --onlyreqdeps Crypt_Blowfish Crypt_CHAP Crypt_DiffieHellman Crypt_GPG
pear install --onlyreqdeps Crypt_HMAC2 Crypt_RC42 Crypt_RSA
pear install --onlyreqdeps File_Archive File_CSV File_PDF HTTP Image_Barcode Image_Graph
pear install --onlyreqdeps Image_QRCode Inline_C Math_BinaryUtils Math_Derivative
pear install --onlyreqdeps Math_Polynomial Math_Quaternion Math_Complex Math_Matrix
pear install --onlyreqdeps Math_Vector MDB2 Net_URL2 Services_JSON System_Command System_Daemon
pear install --onlyreqdeps Cache_Lite-1.7.16
pear install --onlyreqdeps HTTP_Request2-2.2.1
pear install --onlyreqdeps XML_Parser XML_RPC2
# GROUP-END:php
EOF

# Configuring boot splash image
report_info "Configuring boot splash image"
$CHROOT <<EOF
systemctl enable splashscreen.service
EOF

# Configuring udiskie for USB automount
report_info "Configuring udiskie for USB automount"
$CHROOT <<EOF
systemctl enable udiskie.service
EOF

# Removing plymouth
report_info "Removing plymouth"
$CHROOT <<EOF
apt-get purge plymouth -y
dpkg --configure -a
# Add true here to avoid having a dpkg error abort the whole script here
true
EOF

# Add image specific tasks

# Specific tasks for the full image
if [ "$CONFIG_NAME" = "full" ]
then
	report_info "Image specific tasks"

	# Removing lightdm display manager
	report_info "Removing lightdm display manager"
	$CHROOT <<EOF
apt-get purge lightdm lightdm-* -y
EOF

	# Installing Mali GPU 2D driver
	report_info "Installing Mali GPU 2D driver"
	$CHROOT <<EOF
cd /tmp
tar jxf xf86-video-fbturbo-armhf-built.tar.bz2
cd xf86-video-fbturbo-armhf-built
make install
cp /tmp/xorg.conf /usr/share/X11/xorg.conf.d/99-sunxifb.conf
cp /tmp/xorg.conf /etc/X11/xorg.conf
EOF

	# Adding reboot and shutdown buttons to the panel
	report_info "Adding reboot and shutdown buttons to the panel"
	$CHROOT <<EOF
cd /tmp/panel-buttons
cp dialog-reboot /sbin/
cp dialog-shutdown /sbin/
chown tf.tf /sbin/dialog-reboot
chown tf.tf /sbin/dialog-shutdown
cp tinkerforge-system-reboot.png /usr/share/icons/
cp tinkerforge-system-shutdown.png /usr/share/icons/
cp system-reboot.desktop /usr/share/applications/
cp system-shutdown.desktop /usr/share/applications/
EOF

	# Setting up XDM logo and desktop wallpaper
	report_info "Setting up XDM logo and desktop wallpaper"
	$CHROOT <<EOF
rm -rf /etc/alternatives/desktop-background
ln -s /usr/share/images/tf-image.png /etc/alternatives/desktop-background
EOF

	# Installing brickv
	if [ "$USE_LOCAL_PACKAGES" = "yes" ] && [ -f $BASE_DIR/local_packages/brickv_linux_latest.deb ]
	then
		report_info "Installing brickv (using local package)"
		cp $BASE_DIR/local_packages/brickv_linux_latest.deb $ROOTFS_DIR/tmp
	else
		report_info "Installing brickv"
		wget -P $ROOTFS_DIR/tmp http://download.tinkerforge.com/tools/brickv/linux/brickv_linux_latest.deb
	fi

	$CHROOT <<EOF
dpkg -i /tmp/brickv_linux_latest.deb
dpkg --configure -a
# Add true here to avoid having a dpkg error abort the whole script here
true
EOF
fi

# Setting Java class path
report_info "Setting Java class path"
$CHROOT <<EOF
echo "
# Setting Java class path
CLASSPATH=\$CLASSPATH:/usr/share/java
export CLASSPATH" >> /etc/profile
EOF

# Fixing, cleaning and updating APT
report_info "Fixing, cleaning and updating APT"
$CHROOT <<EOF
cat /etc/apt/sources.list.d/* > /tmp/sources.list.tmp
rm -rf /etc/apt/sources.list.d/*
if [ -n "$aptcacher" ]
then
    sed -e 's/'`hostname`':315\([0-9]\+\)\///' /tmp/sources.list.tmp > /etc/apt/sources.list
else
    cat /tmp/sources.list.tmp > /etc/apt/sources.list
fi
/etc/init.d/hostname.sh
apt-get clean
apt-get update
apt-get -f install -y
EOF

# Setting up fake-hwclock
report_info "Setting up fake-hwclock"
$CHROOT <<EOF
rm -rf /etc/cron.hourly/fake-hwclock
chmod 0644 /etc/cron.d/fake-hwclock
systemctl disable hwclock.sh
fake-hwclock
EOF

# Copy RED Brick index website
report_info "Copy RED Brick index website"
$CHROOT <<EOF
cp /tmp/index.py /home/tf
chown tf:tf /home/tf/index.py
cp /tmp/red.css /home/tf
chown tf:tf /home/tf/red.css
EOF

# Updating user PATH
report_info "Updating user PATH"
$CHROOT <<EOF
echo "
# Updating user PATH
PATH=\$PATH:/sbin:/usr/sbin
export PATH" >> /etc/profile
EOF

# Reconfiguring locale
report_info "Reconfiguring locale"
$CHROOT <<EOF
echo $LOCALE_CHARSET > /etc/locale.gen
locale-gen
update-locale LANG=$LOCALE LANGUAGE=$LANGUAGE LC_ALL=$LOCALE
setupcon
dpkg --configure -a
# Add true here to avoid having a dpkg error aborit the whole script here
true
EOF

# Fix Apache server name problem
report_info "Fix Apache server name problem"
$CHROOT <<EOF
cp -ar /tmp/apache2.conf /etc/apache2/
EOF

# Generate Tinkerforge.js symlink
report_info "Generating Tinkerforge.js symlink"
$CHROOT <<EOF
ln -s /usr/tinkerforge/bindings/javascript/browser/source/Tinkerforge.js /home/tf
EOF

# Compiling and installing hostapd
report_info "Compiling and installing hostapd"
$CHROOT <<EOF
cd /tmp
tar jxf hostap_2_6.tar.bz2
mkdir -p /etc/hostapd
cd ./hostap_2_6/hostapd
make clean
make all
make install
chmod 755 /etc/init.d/hostapd
EOF

# Installing NetworkManager

# NetworkManager is installed this way instead of by multistrap because
# if installed with multustrap it will ignore the recommended packages
# which are required for proper operation of NetworkManager.
report_info "Installing NetworkManager"
$CHROOT <<EOF
apt-get install network-manager -y \
network-manager-gnome \
network-manager-pptp \
network-manager-pptp-gnome
cd /tmp
cp NetworkManager.conf /etc/NetworkManager
EOF

# Installing ModemManager
report_info "Installing ModemManager"
$CHROOT <<EOF
cd /tmp
apt-get purge modemmanager -y
apt-get install ./modemmanager_1.6.4-1_armhf.deb
apt-mark hold modemmanager
EOF

# Do not run DNS/DHCP server at boot by default
report_info "Do not run DNS/DHCP server at boot by default"
$CHROOT <<EOF
systemctl disable dnsmasq
EOF

# Enabling X11 server in RED Brick way
report_info "Enabling X server in RED Brick way"
$CHROOT <<EOF
touch /etc/tf_x11_enabled
EOF

# Enabling GPU 2D Only
report_info "Enabling GPU 2D Only"
$CHROOT <<EOF
touch /etc/tf_gpu_2d_only
EOF

# Remove Apache init script dependency of DNS server
report_info "Remove Apache init script dependency of DNS server"
$CHROOT <<EOF
sed -i 's/\$named//g' /etc/init.d/apache2
EOF

# Installing tinkerforge touch calibrator
report_info "Installing tinkerforge touch calibrator"
$CHROOT <<EOF
cp /tmp/tinkerforge_touch_calibrator/tinkerforge_touch_calibrator.png /usr/share/icons
cp /tmp/tinkerforge_touch_calibrator/tinkerforge_touch_calibrator.py /usr/bin
cp /tmp/tinkerforge_touch_calibrator/tinkerforge_touch_calibrator.desktop /home/tf/Desktop
chmod 777 /usr/share/X11/xorg.conf.d
EOF

# Enabling setuid of /bin/ping
report_info "Enabling setuid of /bin/ping"
$CHROOT <<EOF
chmod u+s /bin/ping
EOF

# Installing OpenHAB2
report_info "Installing OpenHAB2"
$CHROOT <<EOF
wget -qO - 'https://bintray.com/user/downloadSubjectPublicKey?username=openhab' | apt-key add -
echo 'deb https://dl.bintray.com/openhab/apt-repo2 stable main' | tee /etc/apt/sources.list.d/openhab2.list
apt-get update
apt-get install openhab2 openhab2-addons openhab2-addons-legacy -y
systemctl daemon-reload
systemctl stop openhab2
systemctl disable openhab2
cp /tmp/openhab2/addons.cfg /etc/openhab2/services/addons.cfg
cp /tmp/openhab2/tinkerforge.cfg /etc/openhab2/services/tinkerforge.cfg
chown -R openhab.openhab /etc/openhab2/
EOF

# To save image build time the archive is created from Nagios
# source which is already built and ready to execute install commands

# Installing Nagios
report_info "Installing Nagios"
$CHROOT <<EOF
useradd nagios
groupadd nagcmd
usermod -a -G nagcmd nagios
usermod -a -G nagcmd www-data
cd /tmp
tar jxvf nagios-4.3.2-armhf-built.tar.bz2
cd nagios-4.3.2-armhf-built
make install
make install-init
make install-config
make install-commandmode
a2enmod rewrite
a2enmod cgi
cp sample-config/httpd.conf /etc/apache2/sites-available/nagios4.conf
chmod 644 /etc/apache2/sites-available/nagios4.conf
a2ensite nagios4.conf
htpasswd -b -c /usr/local/nagios/etc/htpasswd.users nagiosadmin tf
cp nagios.cfg /usr/local/nagios/etc
cp resource.cfg /usr/local/nagios/etc
cp nagios.service /etc/systemd/system
EOF

# Installing signing key of official Mono repository
report_info "Installing signing key of official Mono repository"
$CHROOT <<EOF
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF
apt-get update
EOF

if [ "$DRAFT_MODE" = "no" ]
then
	# Generating dpkg listing
	report_info "Generating dpkg listing"
	$CHROOT <<EOF
dpkg-query -W -f='\${Package}<==>\${Version}<==>\${Description}\n' > /root/dpkg-$CONFIG_NAME.listing
EOF
	mv $ROOTFS_DIR/root/dpkg-$CONFIG_NAME.listing $BUILD_DIR

	# Generating Perl listing
	report_info "Generating Perl listing"
	$CHROOT <<EOF
pmall > /root/perl-$CONFIG_NAME.listing
EOF
	mv $ROOTFS_DIR/root/perl-$CONFIG_NAME.listing $BUILD_DIR

	# Generating PHP listing
	report_info "Generating PHP listing"
	$CHROOT <<EOF
mv /usr/share/php/PEAR/Frontend/CLI.php /usr/share/php/PEAR/Frontend/CLI.php.org
mv /tmp/pear-CLI.php /usr/share/php/PEAR/Frontend/CLI.php
pear list-all > /dev/null
mv /usr/share/php/PEAR/Frontend/CLI.php.org /usr/share/php/PEAR/Frontend/CLI.php
mv /root/php.listing /root/php-$CONFIG_NAME.listing
EOF
	mv $ROOTFS_DIR/root/php-$CONFIG_NAME.listing $BUILD_DIR

	# Generating Python listing
	report_info "Generating Python listing"
	$CHROOT <<EOF
mv /usr/lib/python2.7/dist-packages/pip/commands/list.py /usr/lib/python2.7/dist-packages/pip/commands/list.py.org
mv /tmp/pip-list.py /usr/lib/python2.7/dist-packages/pip/commands/list.py
pip list --format=legacy > /root/python.listing
mv /usr/lib/python2.7/dist-packages/pip/commands/list.py.org /usr/lib/python2.7/dist-packages/pip/commands/list.py
mv /root/python.listing /root/python-$CONFIG_NAME.listing
EOF
	mv $ROOTFS_DIR/root/python-$CONFIG_NAME.listing $BUILD_DIR

	# Generating Ruby listing
	report_info "Generating Ruby listing"
	$CHROOT <<EOF
gem list --local --details > /root/ruby-$CONFIG_NAME.listing
EOF
	mv $ROOTFS_DIR/root/ruby-$CONFIG_NAME.listing $BUILD_DIR
fi

# Disabling apt-daily
report_info "Disabling apt-daily"
$CHROOT <<EOF
systemctl disable apt-daily.timer
systemctl disable apt-daily.service
systemctl disable apt-daily-upgrade.timer
systemctl disable apt-daily-upgrade.service
EOF

# Cleaning /tmp directory
report_info "Cleaning /tmp directory"
rm -rf $ROOTFS_DIR/tmp/*

# Updating locate database
report_info "Updating locate database"
$CHROOT <<EOF
updatedb
EOF

# Disabling the root user
report_info "Disabling the root user"
$CHROOT <<EOF
passwd -l root
EOF

# Clearing bash history of the root user
report_info "Clearing bash history of the root user"
rm -rf $ROOTFS_DIR/root/.bash_history
touch $ROOTFS_DIR/root/.bash_history

# Removing qemu-arm-static from the root file system
report_info "Removing qemu-arm-static from the root-fs"
rm -rf $ROOTFS_DIR$QEMU_BIN

# Unmounting stuff from the root-fs
unmount

# Enable starting daemons in the chroot
report_info "Enable starting daemons in the chroot"
rm -rf $ROOTFS_DIR/usr/sbin/policy-rc.d

# Ensure host name integrity
report_info "Ensure host name integrity"
hostname -F /etc/hostname

if [ "$DRAFT_MODE" = "no" ]
then
	# Generate feature table
	report_info "Generating feature table"
	pushd $BASE_DIR > /dev/null
	./generate-feature-doc.py $CONFIG_NAME && cp $PATCHES_DIR/root-fs/common/etc/tf_installed_versions $ROOTFS_DIR/etc/
	popd > /dev/null
fi

# Built file that indicates rootfs was made
touch $BUILD_DIR/root-fs-$CONFIG_NAME.built

trap - SIGHUP SIGINT SIGTERM SIGQUIT EXIT
cleanup
report_process_finish

exit 0
