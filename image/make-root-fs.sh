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

# Checking qemu support
if [ ! -e $QEMU_BIN ]
then
    report_error "Install qemu support for ARM"
    exit 1
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

# Cleaning up listing files
report_info "Cleaning up listing files"
if [ -d $BUILD_DIR ]
then
    rm -rf $BUILD_DIR/*.listing
fi

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

# Copying qemu-arm-static to root-fs
report_info "Copying qemu-arm-static to root-fs"
cp $QEMU_BIN $ROOTFS_DIR/usr/bin/

# Configuring the generated root-fs
report_info "Configuring the generated root-fs"
cp /etc/resolv.conf $ROOTFS_DIR/etc/resolv.conf
chroot $ROOTFS_DIR<<EOF
umount /proc
mount -t proc proc /proc
export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true
export LC_ALL=C LANGUAGE=C LANG=C LC_CTYPE=$LOCALE
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
umount /proc
EOF

# Installing Java 8
report_info "Installing Java 8"
chroot $ROOTFS_DIR<<EOF
umount /proc
mount -t proc proc /proc
cd /tmp
wget download.tinkerforge.com/_stuff/jdk-8-linux-arm-vfp-hflt.tar.gz
tar zxvf jdk-8-linux-arm-vfp-hflt.tar.gz -C /usr/lib/jvm
update-alternatives --install /usr/bin/javac javac /usr/lib/jvm/jdk1.8.0/bin/javac 1
update-alternatives --install /usr/bin/java java /usr/lib/jvm/jdk1.8.0/bin/java 1
echo 3 | update-alternatives --config javac
echo 3 | update-alternatives --config java
umount /proc
EOF

# Installing brickd
report_info "Installing brickd"
chroot $ROOTFS_DIR<<EOF
umount /proc
mount -t proc proc /proc
export LC_ALL=C LANGUAGE=C LANG=C LC_CTYPE=$LOCALE
cd /tmp
wget http://download.tinkerforge.com/tools/brickd/linux/brickd_linux_latest_armhf.deb
dpkg -i brickd_linux_latest_armhf.deb
dpkg --configure -a
umount /proc
EOF

# Installing Node.JS and NPM
report_info "Installing Node.JS and NPM"
chroot $ROOTFS_DIR<<EOF
umount /proc
mount -t proc proc /proc
export LC_ALL=C LANGUAGE=C LANG=C LC_CTYPE=$LOCALE
cd /tmp
dpkg -i node_*
dpkg --configure -a
umount /proc
EOF

# Updating Perl modules
report_info "Updating Perl modules"
chroot $ROOTFS_DIR<<EOF
umount /proc
mount -t proc proc /proc
export LC_ALL=C LANGUAGE=C LANG=C LC_CTYPE=$LOCALE
rm -rf /root/.cpanm/
# GROUP-START:perl
cpanm install -n Thread::Queue
# GROUP-END:perl
umount /proc
EOF

# Setting up all the bindings
report_info "Setting up all the bindings"
chroot $ROOTFS_DIR<<EOF
umount /proc
mount -t proc proc /proc
export LC_ALL=C LANGUAGE=C LANG=C LC_CTYPE=$LOCALE LC_CTYPE=$LOCALE
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
umount /proc
EOF

# Installing Mono features
report_info "Installing Mono features"
chroot $ROOTFS_DIR<<EOF
umount /proc
mount -t proc proc /proc
export LC_ALL=C LANGUAGE=C LANG=C LC_CTYPE=$LOCALE
cd /tmp/features/mono_features/
unzip ./MathNet.Numerics-2.6.1.30.zip -d ./MathNet.Numerics
unzip ./mysql-connector-net-6.8.3-noinstall.zip -d ./mysql-connector-net
unzip ./SharpPcap-4.2.0.bin.zip
unzip ./sharpPDF_2_0_Beta2_dll.zip -d ./sharpPDF
unzip ./xml-rpc.net.2.5.0.zip -d ./xml-rpc.net
cd ./MathNet.Numerics/portable/
cp ./*.dll /usr/lib/mono/2.0/
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
cd /tmp/features/mono_features/sharpPDF/
cp ./*.dll /usr/lib/mono/2.0/
cd /tmp/features/mono_features/xml-rpc.net/
cp ./*.dll /usr/lib/mono/2.0/
if  [ "$CONFIG_NAME" = "full" ]
then
    cd /tmp/features/mono_features/
    unzip OpenTK_1.1.1599.6049.zip
    cd ./OpenTK
    cp ./*.dll /usr/lib/mono/2.0/
fi
umount /proc
EOF

# Installing JAVA features
report_info "Installing JAVA features"
chroot $ROOTFS_DIR<<EOF
umount /proc
mount -t proc proc /proc
export LC_ALL=C LANGUAGE=C LANG=C LC_CTYPE=$LOCALE
cd /tmp//features/java_features/
cp ./*.jar /usr/lib/jvm/java-6-openjdk-armhf/jre/lib/
cp ./*.jar /usr/lib/jvm/java-7-openjdk-armhf/jre/lib/
cp ./*.jar /usr/lib/jvm/jdk1.8.0/jre/lib/
umount /proc
EOF

# Installing Ruby features
report_info "Installing Ruby features"
chroot $ROOTFS_DIR<<EOF
umount /proc
mount -t proc proc /proc
export LC_ALL=C LANGUAGE=C LANG=C LC_CTYPE=$LOCALE
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
umount /proc
EOF

# Installing Python features
report_info "Installing Python features"
chroot $ROOTFS_DIR<<EOF
umount /proc
mount -t proc proc /proc
export LC_ALL=C LANGUAGE=C LANG=C LC_CTYPE=$LOCALE
easy_install --upgrade pip
# GROUP-START:python
pip install pycrypto
# GROUP-END:python
umount /proc
EOF

# Installing Perl features
report_info "Installing Perl features"
chroot $ROOTFS_DIR<<EOF
umount /proc
mount -t proc proc /proc
export LC_ALL=C LANGUAGE=C LANG=C LC_CTYPE=$LOCALE
# GROUP-START:perl
cpanm install -n RPC::Simple
# GROUP-END:perl
umount /proc
EOF

# Installing PHP features
report_info "Installing PHP features"
chroot $ROOTFS_DIR<<EOF
umount /proc
mount -t proc proc /proc
export LC_ALL=C LANGUAGE=C LANG=C LC_CTYPE=$LOCALE
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
umount /proc
EOF

# Installing Node.JS features
#report_info "Installing Node.JS features"
#chroot $ROOTFS_DIR<<EOF
#export LC_ALL=C LANGUAGE=C LANG=C LC_CTYPE=$LOCALE
#npm -g install node-dbi
#npm -g install gui node-qt node-opengl
#npm -g install science gsl numbers ico
#npm -g install crypto
#npm -g install node-pcap node-curl
#npm -g install htmlparser
#npm -g install opencv
#npm -g install dnode now pdfkit
#EOF

# Enable BASH completion
report_info "Enabling BASH completion"
chroot $ROOTFS_DIR<<EOF
umount /proc
mount -t proc proc /proc
export LC_ALL=C LANGUAGE=C LANG=C LC_CTYPE=$LOCALE
. /etc/bash_completion
umount /proc
EOF

# Setting root password
report_info "Setting root password"
chroot $ROOTFS_DIR<<EOF
umount /proc
mount -t proc proc /proc
export LC_ALL=C LANGUAGE=C LANG=C LC_CTYPE=$LOCALE
passwd root
tinkerforge
tinkerforge
umount /proc
EOF

# Configuring boot splash image
report_info "Configuring boot splash image"
chroot $ROOTFS_DIR<<EOF
umount /proc
mount -t proc proc /proc
export LC_ALL=C LANGUAGE=C LANG=C LC_CTYPE=$LOCALE
chmod 755 /etc/init.d/asplashscreen
chmod 755 /etc/init.d/killasplashscreen
insserv /etc/init.d/asplashscreen
insserv /etc/init.d/killasplashscreen
umount /proc
EOF

# Removing plymouth
report_info "Removing plymouth"
chroot $ROOTFS_DIR<<EOF
umount /proc
mount -t proc proc /proc
export LC_ALL=C LANGUAGE=C LANG=C LC_CTYPE=$LOCALE
apt-get purge plymouth -y
dpkg --configure -a
umount /proc
EOF

# Add image specific tasks

# Specific tasks for the full image
if [ "$CONFIG_NAME" = "full" ]
then
	report_info "Image specific tasks"

	# Configuring Mali GPU
	report_info "Configuring Mali GPU"
	chroot $ROOTFS_DIR<<EOF
umount /proc
mount -t proc proc /proc
export LC_ALL=C LANGUAGE=C LANG=C LC_CTYPE=$LOCALE
cd /tmp/mali-gpu
dpkg -i ./libdri2-1_1.0-2_armhf.deb
dpkg -i ./libsunxi-mali-x11_1.0-4_armhf.deb
dpkg -i ./libvdpau-sunxi_1.0-1_armhf.deb
dpkg -i ./libvpx0_0.9.7.p1-2_armhf.deb
dpkg -i ./sunxi-disp-test_1.0-1_armhf.deb
dpkg -i ./udevil_0.4.1-3_armhf.deb
dpkg -i ./xserver-xorg-video-sunximali_1.0-3_armhf.deb
dpkg --configure -a
umount /proc
EOF

	# Setting up XDM logo and desktop wallpaper
	report_info "Setting up XDM logo and desktop wallpaper"
	chroot $ROOTFS_DIR<<EOF
umount /proc
mount -t proc proc /proc
export LC_ALL=C LANGUAGE=C LANG=C LC_CTYPE=$LOCALE
rm -rf /etc/alternatives/desktop-background
ln -s /usr/share/images/tf-image.png /etc/alternatives/desktop-background
umount /proc
EOF

	# Installing brickv
	report_info "Installing brickv"
	chroot $ROOTFS_DIR<<EOF
umount /proc
mount -t proc proc /proc
export LC_ALL=C LANGUAGE=C LANG=C LC_CTYPE=$LOCALE
cd /tmp
wget http://download.tinkerforge.com/tools/brickv/linux/brickv_linux_latest.deb
dpkg -i brickv_linux_latest.deb
dpkg --configure -a
umount /proc
EOF
fi

# Cleaning /tmp directory
report_info "Cleaning /tmp directory"
chroot $ROOTFS_DIR<<EOF
umount /proc
mount -t proc proc /proc
export LC_ALL=C LANGUAGE=C LANG=C LC_CTYPE=$LOCALE
rm -rf /tmp/*
umount /proc
EOF

# Setting JAVA class path
report_info "Setting JAVA class path"
chroot $ROOTFS_DIR<<EOF
umount /proc
mount -t proc proc /proc
export LC_ALL=C LANGUAGE=C LANG=C LC_CTYPE=$LOCALE
echo "
# Setting JAVA class path
CLASSPATH=\$CLASSPATH:/usr/lib/jvm/java-6-openjdk-armhf/jre/lib/:/usr/lib/jvm/java-7-openjdk-armhf/jre/lib/:/usr/lib/jvm/jdk1.8.0/jre/lib/
export CLASSPATH" >> /etc/profile
umount /proc
EOF

# Setting Mono path
report_info "Setting Mono path"
chroot $ROOTFS_DIR<<EOF
umount /proc
mount -t proc proc /proc
export LC_ALL=C LANGUAGE=C LANG=C LC_CTYPE=$LOCALE
echo "
# Setting Mono path
MONO_PATH=\$MONO_PATH:/usr/lib/mono/2.0/:/usr/lib/mono/3.5/:/usr/lib/mono/4.0/:/usr/lib/mono/4.5/
export MONO_PATH" >> /etc/profile
umount /proc
EOF

# Fixing, cleaning and updating APT
report_info "Fixing, cleaning and updating APT"
chroot $ROOTFS_DIR<<EOF
umount /proc
mount -t proc proc /proc
export LC_ALL=C LANGUAGE=C LANG=C LC_CTYPE=$LOCALE
cat /etc/apt/sources.list.d/* > /tmp/sources.list.tmp
rm -rf /etc/apt/sources.list.d/*
if [ -n "$aptcacher" ]
then
    sed -e 's/'`hostname`':315\([0-9]\+\)\///' /tmp/sources.list.tmp > /etc/apt/sources.list
else
	cat /tmp/sources.list.tmp > /etc/apt/sources.list
fi
rm -rf /tmp/*
apt-get clean
apt-get update
apt-get -f install
umount /proc
EOF

# Setting up running-led
report_info "Setting up running-led"
chroot $ROOTFS_DIR<<EOF
umount /proc
mount -t proc proc /proc
export LC_ALL=C LANGUAGE=C LANG=C LC_CTYPE=$LOCALE
chmod a+x /etc/init.d/running-led
insserv /etc/init.d/running-led
umount /proc
EOF

# Setting up fake-hwclock
report_info "Setting up fake-hwclock"
chroot $ROOTFS_DIR<<EOF
umount /proc
mount -t proc proc /proc
export LC_ALL=C LANGUAGE=C LANG=C LC_CTYPE=$LOCALE
rm -rf /etc/cron.hourly/fake-hwclock
chmod a+x /etc/cron.d/fake-hwclock
insserv -r /etc/init.d/hwclock.sh
fake-hwclock
umount /proc
EOF

# Adding new user
report_info "Adding new user"
chroot $ROOTFS_DIR<<EOF
umount /proc
mount -t proc proc /proc
export LC_ALL=C LANGUAGE=C LANG=C LC_CTYPE=$LOCALE
rm -rf /home/
adduser rbuser
tinkerforge
tinkerforge
RED Brick User




Y
umount /proc
EOF

# User group setup
report_info "User group setup"
chroot $ROOTFS_DIR<<EOF
umount /proc
mount -t proc proc /proc
export LC_ALL=C LANGUAGE=C LANG=C LC_CTYPE=$LOCALE
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
umount /proc
EOF

# Generating dpkg listing
report_info "Generating dpkg listing"
chroot $ROOTFS_DIR<<EOF
umount /proc
mount -t proc proc /proc
export LC_ALL=C LANGUAGE=C LANG=C LC_CTYPE=$LOCALE
dpkg-query -W -f='\${Package}<==>\${Version}<==>\${Description}\n' > /root/dpkg-$CONFIG_NAME.listing
umount /proc
EOF
mv $ROOTFS_DIR/root/dpkg-$CONFIG_NAME.listing $BUILD_DIR

# Generating Perl listing
report_info "Generating Perl listing"
chroot $ROOTFS_DIR<<EOF
umount /proc
mount -t proc proc /proc
export LC_ALL=C LANGUAGE=C LANG=C LC_CTYPE=$LOCALE
pmall > /root/perl-$CONFIG_NAME.listing
umount /proc
EOF
mv $ROOTFS_DIR/root/perl-$CONFIG_NAME.listing $BUILD_DIR

# Generating PHP listing
report_info "Generating PHP listing"
chroot $ROOTFS_DIR<<EOF
umount /proc
mount -t proc proc /proc
export LC_ALL=C LANGUAGE=C LANG=C LC_CTYPE=$LOCALE
pear list-all | sed 's/pear\/\///' > /root/php-$CONFIG_NAME.listing
umount /proc
EOF
mv $ROOTFS_DIR/root/php-$CONFIG_NAME.listing $BUILD_DIR

# Generating Python listing
# TODO

# Generating Ruby listing
report_info "Generating Ruby listing"
chroot $ROOTFS_DIR<<EOF
umount /proc
mount -t proc proc /proc
export LC_ALL=C LANGUAGE=C LANG=C LC_CTYPE=$LOCALE
gem list --local --details > /root/ruby-$CONFIG_NAME.listing
umount /proc
EOF
mv $ROOTFS_DIR/root/ruby-$CONFIG_NAME.listing $BUILD_DIR

# Reconfiguring locale
report_info "Reconfiguring locale"
chroot $ROOTFS_DIR<<EOF
umount /proc
mount -t proc proc /proc
export LC_ALL=C LANGUAGE=C LANG=C LC_CTYPE=$LOCALE
update-locale LANG=$LOCALE LANGUAGE=$LANGUAGE LC_ALL=$LOCALE
echo $LOCALE_CHARSET > /etc/locale.gen
locale-gen
setupcon
dpkg --configure -a
umount /proc
EOF

# Installing kernel headers
report_info "Installing kernel headers"
rsync -a --no-o --no-g $KERNEL_HEADER_INCLUDE_DIR $ROOTFS_DIR/usr/include
rsync -a --no-o --no-g $KERNEL_HEADER_USR_DIR $ROOTFS_DIR/usr

# Cleaning /etc/resolv.conf
report_info "Cleaning /etc/resolv.conf"
chroot $ROOTFS_DIR<<EOF
umount /proc
mount -t proc proc /proc
export LC_ALL=C LANGUAGE=C LANG=C LC_CTYPE=$LOCALE
rm -rf /etc/resolv.conf
umount /proc
EOF

# Clearing bash history of the root user
report_info "Clearing bash history of the root user"
rm -rf $ROOTFS_DIR/root/.bash_history
touch $ROOTFS_DIR/root/.bash_history

# Removing qemu-arm-static from the root file system
report_info "Removing qemu-arm-static from the root file system"
rm -rf $ROOTFS_DIR$QEMU_BIN

# Ensure host name integrity
report_info "Ensure host name integrity"
hostname -F /etc/hostname

touch $BUILD_DIR/root-fs-$CONFIG_NAME.built

report_info "Process finished"

exit 0
