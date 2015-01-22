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

# Some helper variables and functions
CHROOT="env -i PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin LANG=$LOCALE LANGUAGE=$LANGUAGE LC_ALL=$LOCALE DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true chroot $ROOTFS_DIR"

function unmount {
	report_info "Unmounting /proc and /dev/pts from root-fs"

	set +e

	if [ -d $ROOTFS_DIR/proc ]
	then
		umount -f $ROOTFS_DIR/proc
	fi

	if [ -d $ROOTFS_DIR/dev/pts ]
	then
		umount -f $ROOTFS_DIR/dev/pts
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
rsync -a --no-o --no-g $PATCHES_DIR/root-fs/common/ $ROOTFS_DIR/
rsync -a --no-o --no-g $PATCHES_DIR/root-fs/$CONFIG_NAME/ $ROOTFS_DIR/

# Write /etc/tf_image_version
report_info "Write /etc/tf_image_version"
echo "${IMAGE_DOT_VERSION} (${CONFIG_NAME})" > $ROOTFS_DIR/etc/tf_image_version

# Fix mode of /tmp
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
cp /etc/resolv.conf $ROOTFS_DIR/etc/resolv.conf
$CHROOT <<EOF
wget http://archive.raspbian.org/raspbian.public.key -O - | apt-key add -
wget http://archive.raspberrypi.org/debian/raspberrypi.gpg.key -O - | apt-key add -
/var/lib/dpkg/info/dash.preinst install
echo "dash dash/sh boolean false" | debconf-set-selections
echo "tzdata tzdata/Areas select $TZDATA_AREA" | debconf-set-selections
echo "tzdata tzdata/Zones/Europe select $TZDATA_ZONE" | debconf-set-selections
update-locale LANG=$LOCALE LANGUAGE=$LANGUAGE LC_ALL=$LOCALE
echo $LOCALE_CHARSET > /etc/locale.gen
locale-gen
echo -e "# KEYBOARD CONFIGURATION FILE

# Consult the keyboard(5) manual page.

XKBMODEL=\"$KB_MODEL\"
XKBLAYOUT=\"$KB_LAYOUT\"
XKBVARIANT=\"$KB_VARIANT\"
XKBOPTIONS=\"$KB_OPTIONS\"

BACKSPACE=\"$KB_BACKSPACE\"
" > /etc/default/keyboard
setupcon
dpkg --configure -a
# add true here to avoid having a dpkg error abort the whole script here
true
EOF

# Installing Java 8
report_info "Installing Java 8"
$CHROOT <<EOF
cd /tmp
wget download.tinkerforge.com/_stuff/jdk-8-linux-arm-vfp-hflt.tar.gz
tar zxf jdk-8-linux-arm-vfp-hflt.tar.gz -C /usr/lib/jvm
update-alternatives --install /usr/bin/javac javac /usr/lib/jvm/jdk1.8.0/bin/javac 1
update-alternatives --install /usr/bin/java java /usr/lib/jvm/jdk1.8.0/bin/java 1
# we only have the java8 javac echo 3 | update-alternatives --config javac
echo 4 | update-alternatives --config java
EOF

# Installing brickd
report_info "Installing brickd"
$CHROOT <<EOF
cd /tmp
wget http://download.tinkerforge.com/tools/brickd/linux/brickd_linux_latest+redbrick_armhf.deb
dpkg -i brickd_linux_latest+redbrick_armhf.deb
dpkg --configure -a
# add true here to avoid having a dpkg error abort the whole script here
true
EOF

# Installing redapid
report_info "Installing redapid"
$CHROOT <<EOF
cd /tmp
wget http://download.tinkerforge.com/tools/redapid/linux/redapid_linux_latest_armhf.deb
dpkg -i redapid_linux_latest_armhf.deb
dpkg --configure -a
# add true here to avoid having a dpkg error abort the whole script here
true
EOF

# Installing Node.js and NPM
report_info "Installing Node.js and NPM"
$CHROOT <<EOF
cd /tmp
dpkg -i node_*
dpkg --configure -a
# add true here to avoid having a dpkg error abort the whole script here
true
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
export FPCDIR=/usr/lib/fpc/`ls /usr/lib/fpc/ | grep -E [0-9].[0-9].[0-9] | head -n1`
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
. /etc/bash_completion
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
rsync -a --no-o --no-g $BUILD_DIR/nodejs_tmp/lib $ROOTFS_DIR/usr/local
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
easy_install --upgrade pip
# GROUP-START:python
pip install pycrypto
pip install flask
# GROUP-END:python
pip install --upgrade netifaces
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

# Enable BASH completion
report_info "Enabling BASH completion"
$CHROOT <<EOF
. /etc/bash_completion
EOF

# Configuring boot splash image
report_info "Configuring boot splash image"
$CHROOT <<EOF
chmod 755 /etc/init.d/asplashscreen
chmod 755 /etc/init.d/killasplashscreen
update-rc.d asplashscreen defaults
update-rc.d killasplashscreen defaults
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
dpkg -i ./libdri2-1_1.0-2_armhf.deb
dpkg -i ./libsunxi-mali-x11_1.0-4_armhf.deb
dpkg -i ./libvdpau-sunxi_1.0-1_armhf.deb
dpkg -i ./libvpx0_0.9.7.p1-2_armhf.deb
dpkg -i ./sunxi-disp-test_1.0-1_armhf.deb
dpkg -i ./udevil_0.4.1-3_armhf.deb
dpkg -i ./xserver-xorg-video-sunximali_1.0-3_armhf.deb
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
	report_info "Installing brickv"
	$CHROOT <<EOF
cd /tmp
wget http://download.tinkerforge.com/tools/brickv/linux/brickv_linux_latest.deb
dpkg -i brickv_linux_latest.deb
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
apt-get clean
apt-get update
apt-get -f install
EOF

# Setting up fake-hwclock
report_info "Setting up fake-hwclock"
$CHROOT <<EOF
rm -rf /etc/cron.hourly/fake-hwclock
chmod 0644 /etc/cron.d/fake-hwclock
update-rc.d -f hwclock.sh remove
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
cp /tmp/red.css /home/tf
EOF

# Generating dpkg listing
report_info "Generating dpkg listing"
$CHROOT <<EOF
dpkg-query -W -f='\${Package}<==>\${Version}<==>\${Description}\n' > /root/dpkg-$CONFIG_NAME.listing
cat /usr/local/lib/node_modules/npm/package.json | \
python -c "import json;import sys;json_content = unicode(sys.stdin.read());\
json_obj=json.loads(json_content);\
print unicode(json_obj['name'])+'<==>'+unicode(json_obj['version'])+'<==>'+unicode(json_obj['description'])" \
>> /root/dpkg-$CONFIG_NAME.listing
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
mv /tmp/CLI.php /usr/share/php/PEAR/Frontend/
pear list-all > /dev/null
mv /usr/share/php/PEAR/Frontend/CLI.php.org /usr/share/php/PEAR/Frontend/CLI.php
mv /root/php.listing /root/php-$CONFIG_NAME.listing
EOF
mv $ROOTFS_DIR/root/php-$CONFIG_NAME.listing $BUILD_DIR

# Generating Python listing
report_info "Generating Python listing"
$CHROOT <<EOF
mv /usr/local/lib/python2.7/dist-packages/pip-1.5.6-py2.7.egg/pip/commands/list.py /usr/local/lib/python2.7/dist-packages/pip-1.5.6-py2.7.egg/pip/commands/list.py.org
mv /tmp/list.py /usr/local/lib/python2.7/dist-packages/pip-1.5.6-py2.7.egg/pip/commands/
pip list > /root/python.listing
mv /usr/local/lib/python2.7/dist-packages/pip-1.5.6-py2.7.egg/pip/commands/list.py.org /usr/local/lib/python2.7/dist-packages/pip-1.5.6-py2.7.egg/pip/commands/list.py
mv /root/python.listing /root/python-$CONFIG_NAME.listing
EOF
mv $ROOTFS_DIR/root/python-$CONFIG_NAME.listing $BUILD_DIR

# Generating Ruby listing
report_info "Generating Ruby listing"
$CHROOT <<EOF
gem list --local --details > /root/ruby-$CONFIG_NAME.listing
EOF
mv $ROOTFS_DIR/root/ruby-$CONFIG_NAME.listing $BUILD_DIR

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
update-locale LANG=$LOCALE LANGUAGE=$LANGUAGE LC_ALL=$LOCALE
echo $LOCALE_CHARSET > /etc/locale.gen
locale-gen
setupcon
dpkg --configure -a
# add true here to avoid having a dpkg error aborit the whole script here
true
EOF

# Installing kernel headers
report_info "Installing kernel headers"
rsync -a --no-o --no-g $KERNEL_HEADER_INCLUDE_DIR $ROOTFS_DIR/usr/
rsync -a --no-o --no-g $KERNEL_HEADER_USR_DIR $ROOTFS_DIR

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
mkdir ./$HOSTAPD_WPA_SUPPLICANT_NAME
tar jxvf $HOSTAPD_WPA_SUPPLICANT_NAME\
$HOSTAPD_WPA_SUPPLICANT_VERSION\
$HOSTAPD_WPA_SUPPLICANT_EXTENSION -C ./$HOSTAPD_WPA_SUPPLICANT_NAME
mkdir -p /etc/hostapd
cd ./$HOSTAPD_WPA_SUPPLICANT_NAME
cd ./$HOSTAPD_WPA_SUPPLICANT_NAME/hostapd
make clean
make
make install
cd ../wpa_supplicant
make clean
make
make install
chmod 755 /etc/init.d/hostapd
EOF

# Do not run DNS/DHCP server at boot by default
report_info "Do not run DNS/DHCP server at boot by default"
$CHROOT <<EOF
update-rc.d -f dnsmasq remove
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

# Cleaning /tmp directory and make it r/w for everyone
report_info "Cleaning /tmp directory"
$CHROOT <<EOF
rm -rf /tmp/*
updatedb
chmod a+rw /tmp/
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

# Generate feature table
report_info "Generating feature table"
cd $BASE_DIR
./generate-feature-doc.py $CONFIG_NAME

# Built file that indicates rootfs was made
touch $BUILD_DIR/root-fs-$CONFIG_NAME.built

report_info "Process finished"

exit 0
