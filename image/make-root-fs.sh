#!/bin/bash -exu

# RED Brick Image Generator
# Copyright (C) 2014-2015 Matthias Bolte <matthias@tinkerforge.com>
# Copyright (C) 2014-2015 Ishraq Ibne Ashraf <ishraq@tinkerforge.com>
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

# Some helper variables and functions
CHROOT="env -i PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin LANG=$LOCALE LANGUAGE=$LANGUAGE LC_ALL=$LOCALE DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true chroot $ROOTFS_DIR"

function unmount {
	report_info "Unmounting /proc, /dev/pts and /dev/(u)random from the root-fs directory"

	set +e

	if [ -d $ROOTFS_DIR/proc ]
	then
		umount -f $ROOTFS_DIR/proc
	fi

	if [ -d $ROOTFS_DIR/dev/pts ]
	then
		umount -f $ROOTFS_DIR/dev/pts
	fi

	if [ -e $ROOTFS_DIR/dev/random ]
	then
		umount -f $ROOTFS_DIR/dev/random
	fi

	if [ -e $ROOTFS_DIR/dev/urandom ]
	then
		umount -f $ROOTFS_DIR/dev/urandom
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

trap "cleanup" SIGHUP SIGINT SIGTERM SIGQUIT

# Checking if kernel and U-Boot were compiled for current configuration
if [ ! -e $BUILD_DIR/u-boot-$CONFIG_NAME.built ]
then
	report_error "U-Boot was not built for the current image configuration"
	exit 1
fi
if [ ! -e $SCRIPT_BIN_FILE ]
then
	report_error "Boot script was not built for the current image configuration"
	exit 1
fi
if [ ! -e $BUILD_DIR/kernel-$CONFIG_NAME.built ]
then
	report_error "Kernel was not built for the current image configuration"
	exit 1
fi
if [ ! -e $BUILD_DIR/kernel-headers-$CONFIG_NAME.built ]
then
	report_error "Kernel headers were not installed for the current image configuration"
	exit 1
fi

# Checking kernel modules
if [ ! -d $KERNEL_SRC_DIR/$KERNEL_MOD_DIR_NAME ]
then
	report_error "Build kernel modules first"
	exit 1
fi

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
	rm -rf $ROOTFS_DIR/*
else
	mkdir -p $ROOTFS_DIR
fi

# Mounting stuff in root-fs directory
report_info "Mounting stuff in root-fs directory"
mkdir -p $ROOTFS_DIR/proc
mount -t proc none $ROOTFS_DIR/proc
mkdir -p $ROOTFS_DIR/dev/pts
mount --bind /dev/pts $ROOTFS_DIR/dev/pts
touch $ROOTFS_DIR/dev/random
mount --bind /dev/random $ROOTFS_DIR/dev/random
touch $ROOTFS_DIR/dev/urandom
mount --bind /dev/urandom $ROOTFS_DIR/dev/urandom

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
#!/bin/sh
exit 101
EOF
chmod a+x $ROOTFS_DIR/usr/sbin/policy-rc.d

# Copying qemu-arm-static to root-fs
report_info "Copying qemu-arm-static to root-fs"
cp $TOOLS_DIR/$QEMU_BASE_NAME/arm-linux-user/qemu-arm $ROOTFS_DIR$QEMU_BIN

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
echo "nagios3-cgi nagios3/adminpassword string tf" | debconf-set-selections
echo "nagios3-cgi nagios3/adminpassword-repeat string tf" | debconf-set-selections
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
# run dpkg a second time to install the nagios packages that might not have been
# installed the first time due to a missing dependency to dnsmasq
dpkg --configure -a
# add true here to avoid having a dpkg error abort the whole script here
true
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

# Installing Java 8
report_info "Installing Java 8"
$CHROOT <<EOF
cd /tmp
wget download.tinkerforge.com/_stuff/jdk-8-linux-arm-vfp-hflt.tar.gz
tar zxf jdk-8-linux-arm-vfp-hflt.tar.gz -C /usr/lib/jvm
update-alternatives --install /usr/bin/javac javac /usr/lib/jvm/jdk1.8.0/bin/javac 1
update-alternatives --install /usr/bin/java java /usr/lib/jvm/jdk1.8.0/bin/java 1
# we only have the java8 javac
#echo 3 | update-alternatives --config javac
echo 2 | update-alternatives --config java
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
# add true here to avoid having a dpkg error abort the whole script here
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
# add true here to avoid having a dpkg error abort the whole script here
true
EOF

# Provide node command using nodejs (for backward compatibility)
report_info "Provide node command using nodejs (for backward compatibility)"
$CHROOT <<EOF
update-alternatives --install /usr/local/bin/node node /usr/bin/nodejs 900
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

# Install nodejs bindings. We can't install them through chroot, since
# qemu does not support netlink (which is necessary for npm).
# So instead we install them in a custom dir on the host system and
# copy them into the rootfs afterwards.
rm -rf $BUILD_DIR/nodejs_tmp
mkdir -p $BUILD_DIR/nodejs_tmp
npm install $ROOTFS_DIR/usr/tinkerforge/bindings/javascript/nodejs/tinkerforge.tgz -g --prefix $BUILD_DIR/nodejs_tmp
rsync -ac --no-o --no-g $BUILD_DIR/nodejs_tmp/lib/node_modules/tinkerforge $ROOTFS_DIR/usr/lib/nodejs
rm -rf $BUILD_DIR/nodejs_tmp

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
cp ./*.dll /usr/lib/mono/2.0/
cd /tmp/features/mono_features/MathNet.Numerics/Net40
cp ./*.dll /usr/lib/mono/4.0/
cd /tmp/features/mono_features/mysql-connector-net/v2.0/
mv ./mysql.data.cf.dll ./MySql.Data.CF.dll
mv ./mysql.data.dll ./MySql.Data.dll
mv ./mysql.data.entity.dll ./MySql.Data.Entity.dll
mv ./mysql.web.dll ./MySql.Web.dll
cp ./MySql.* /usr/lib/mono/2.0/
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
cp ./*.dll /usr/lib/mono/2.0/
cp ./*.config /usr/lib/mono/2.0/
cd /tmp/features/mono_features/itextsharp/
cp ./*.dll /usr/lib/mono/2.0/
cd /tmp/features/mono_features/xml-rpc.net/
cp ./*.dll /usr/lib/mono/2.0/
if  [ "$CONFIG_NAME" = "full" ]
then
	cd /tmp/features/mono_features/
	unzip -q opentk-2014-06-20.zip -d ./OpenTK
	cd ./OpenTK/Binaries/OpenTK/Release/
	cp ./*.dll /usr/lib/mono/2.0/
	cp ./*.config /usr/lib/mono/2.0/
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
# GROUP-START:php
pear install --onlyreqdeps FSM Archive_Tar Archive_Zip
pear install --onlyreqdeps Crypt_Blowfish Crypt_CHAP Crypt_DiffieHellman Crypt_GPG
pear install --onlyreqdeps Crypt_HMAC2 Crypt_RC42 Crypt_RSA
pear install --onlyreqdeps File_Archive File_CSV File_PDF HTTP Image_Barcode Image_Graph
pear install --onlyreqdeps Image_QRCode Inline_C Math_BinaryUtils Math_Derivative
pear install --onlyreqdeps Math_Polynomial Math_Quaternion Math_Complex Math_Matrix
pear install --onlyreqdeps Math_Vector MDB2 Net_URL2 Services_JSON System_Command System_Daemon
pear install --onlyreqdeps XML_Parser XML_RPC
# GROUP-END:php
EOF

# Configuring boot splash image
report_info "Configuring boot splash image"
$CHROOT <<EOF
chmod 755 /etc/init.d/asplashscreen
systemctl enable asplashscreen
EOF

# Removing plymouth
report_info "Removing plymouth"
$CHROOT <<EOF
apt-get purge plymouth -y
dpkg --configure -a
# add true here to avoid having a dpkg error abort the whole script here
true
EOF

# Add image specific tasks

# Specific tasks for the full image
if [ "$CONFIG_NAME" = "full" ]
then
	report_info "Image specific tasks"

	# Configuring Mali GPU
	report_info "Configuring Mali GPU"
	$CHROOT <<EOF
cd /tmp/mali-gpu
dpkg -i libdri2-1_1.0-2_armhf.deb
dpkg -i libsunxi-mali-x11_1.0-6_armhf.deb
dpkg -i libvdpau-sunxi_1.0-1_armhf.deb
dpkg -i sunxi-disp-test_1.0-1_armhf.deb
dpkg -i libump_3.0-0sunxi1_armhf.deb
dpkg -i xserver-xorg-video-sunximali_1.0-4_armhf.deb
dpkg --configure -a
# add true here to avoid having a dpkg error abort the whole script here
true
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
# add true here to avoid having a dpkg error abort the whole script here
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

# Adding new user
report_info "Adding new user"
$CHROOT <<EOF
rm -rf /home/
adduser tf
tf
tf
RED Brick User




Y
EOF

# User group setup
report_info "User group setup"
$CHROOT <<EOF
usermod -a -G adm tf
usermod -a -G dialout tf
usermod -a -G cdrom tf
usermod -a -G sudo tf
usermod -a -G audio tf
usermod -a -G video tf
usermod -a -G plugdev tf
usermod -a -G games tf
usermod -a -G users tf
usermod -a -G ntp tf
usermod -a -G crontab tf
usermod -a -G netdev tf
EOF

# Copy RED Brick index website
report_info "Copy RED Brick index website"
$CHROOT <<EOF
cp /tmp/index.py /home/tf
chown tf:tf /home/tf/index.py
cp /tmp/red.css /home/tf
chown tf:tf /home/tf/red.css
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
pip list > /root/python.listing
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
# add true here to avoid having a dpkg error aborit the whole script here
true
EOF

# Installing kernel headers
report_info "Installing kernel headers"
rsync -ac --no-o --no-g $KERNEL_HEADER_INCLUDE_DIR $ROOTFS_DIR/usr/
rsync -ac --no-o --no-g $KERNEL_HEADER_USR_DIR $ROOTFS_DIR

# Cleaning /etc/resolv.conf and creating symbolic link for resolvconf
report_info "Cleaning /etc/resolv.conf and creating symbolic link for resolvconf"
$CHROOT <<EOF
rm -rf /etc/resolv.conf
ln -s /etc/resolvconf/run/resolv.conf /etc/resolv.conf
EOF

# Disabling the root user
report_info "Disabling the root user"
$CHROOT <<EOF
passwd -l root
EOF

# Fix apache server name problem
report_info "Fix apache server name problem"
$CHROOT <<EOF
cp -ar /tmp/apache2.conf /etc/apache2/
EOF

# Generate Tinkerforge.js symlink
report_info "Generating Tinkerforge.js symlink"
$CHROOT <<EOF
ln -s /usr/tinkerforge/bindings/javascript/browser/source/Tinkerforge.js /home/tf
EOF

# Compiling and installing hostapd and wpa_supplicant for access point mode support
report_info "Compiling and installing hostapd and wpa_supplicant for access point mode support"
$CHROOT <<EOF
cd /tmp
mkdir ./wpa_supplicant_hostapd
tar jxf wpa_supplicant_hostapd_v4.0.2_9000.20130911.tar.bz2 -C ./wpa_supplicant_hostapd
mkdir -p /etc/hostapd
cd ./wpa_supplicant_hostapd
cd ./wpa_supplicant_hostapd/hostapd
make clean
make
make install
cd ../wpa_supplicant
make clean
make
make install
chmod 755 /etc/init.d/hostapd
EOF

# Installing usb_modeswitch for mobile internet.
# Not using the version from repo in this case
# because the repo version is not updated enough
# and doesn't include some devices for auto mode switching
report_info "Installing usb_modeswitch for mobile internet"
$CHROOT <<EOF
cd /tmp
tar jxf usb-modeswitch-2.2.1.tar.bz2
cd ./usb-modeswitch-2.2.1
make all
make install
cd /tmp
tar jxf usb-modeswitch-data-20150115.tar.bz2
cd ./usb-modeswitch-data-20150115
make all
make files-install
make db-install
EOF

# Installing umtskeeper for mobile internet
report_info "Installing umtskeeper for mobile internet"
$CHROOT <<EOF
cd /tmp
tar jxf umtskeeper.tar.bz2 -C /usr
chmod 755 /usr/umtskeeper/sakis3g
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

# Remove apache init script dependency of DNS server
report_info "Remove apache init script dependency of DNS server"
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

# Installing openHAB
report_info "Installing openHAB"
$CHROOT <<EOF
echo 'deb http://repository-openhab.forge.cloudbees.com/release/1.6.2/apt-repo/ /' > /etc/apt/sources.list.d/openhab.list
apt-get update
apt-get install -y --force-yes openhab-runtime openhab-addon-binding-tinkerforge
systemctl daemon-reload
systemctl disable openhab
chown openhab:openhab /usr/share/openhab/webapps/static
EOF

# Cleaning /tmp directory
report_info "Cleaning /tmp directory"
rm -rf $ROOTFS_DIR/tmp/*

# Updating locate database
report_info "Updating locate database"
$CHROOT <<EOF
updatedb
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
	./generate-feature-doc.py $CONFIG_NAME
	popd > /dev/null
fi

# Built file that indicates rootfs was made
touch $BUILD_DIR/root-fs-$CONFIG_NAME.built

cleanup
report_process_finish

exit 0
