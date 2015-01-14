#! /bin/bash -exu

. ./utilities.sh

BASE_DIR=`pwd`
CONFIG_DIR="$BASE_DIR/config"

. $CONFIG_DIR/common.conf

# Add i386 as architecture
report_info "Add i386 as dpkg architecture"

sudo dpkg --add-architecture i386

# Update package index files
report_info "Update package index files"

sudo apt-get update

# Installing tools
report_info "Installing tools (requires root access)"

sudo apt-get install -y $REQUIRED_HOST_PACKAGES
sudo apt-get build-dep -y qemu

# Installing cross compiling toolchain
report_info "Installing cross compiling toolchain"

if [ ! -d $TOOLS_DIR ]
then
	mkdir -p $TOOLS_DIR
fi

pushd $TOOLS_DIR > /dev/null

if [ ! -f ./$TC_FILE_NAME ]
then
	wget $TC_URL
fi

if [ ! -d ./$TC_DIR_NAME ]
then
	tar jxf ./$TC_FILE_NAME
fi

popd > /dev/null

# Compiling advanced cp command
report_info "Compiling advanced cp command"


pushd $TOOLS_DIR > /dev/null

if [ ! -f ./$COREUTILS_BASE_NAME.tar.xz ]
then
	wget http://ftp.gnu.org/gnu/coreutils/$COREUTILS_BASE_NAME.tar.xz
fi

if [ ! -d ./$COREUTILS_BASE_NAME ]
then
	tar xJf ./$COREUTILS_BASE_NAME.tar.xz
fi

pushd ./$COREUTILS_BASE_NAME > /dev/null

if [ ! -f ./$COREUTILS_BASE_NAME.patched ]
then
	patch -p1 -i $PATCHES_DIR/tools/advcp-0.1-$COREUTILS_BASE_NAME.patch
	touch ./$COREUTILS_BASE_NAME.patched
fi

if [ ! -f $ADVCP_BIN ]
then
	./configure
	make
fi

popd > /dev/null
popd > /dev/null

# Compiling qemu-arm-static
report_info "Compiling qemu-arm-static"

pushd $TOOLS_DIR > /dev/null

if [ ! -f ./$QEMU_BASE_NAME.tar.bz2 ]
then
	wget http://wiki.qemu-project.org/download/$QEMU_BASE_NAME.tar.bz2
fi

if [ ! -d ./$QEMU_BASE_NAME ]
then
	tar xjf ./$QEMU_BASE_NAME.tar.bz2
fi

pushd ./$QEMU_BASE_NAME > /dev/null

if [ ! -d ./$QEMU_BASE_NAME.patched ]
then
	patch -p1 -i $PATCHES_DIR/tools/$QEMU_BASE_NAME-sigrst-sigpwr.patch
	touch ./$QEMU_BASE_NAME.patched
fi

if [ ! -f ./arm-linux-user/qemu-arm ]
then
	./configure --target-list="arm-linux-user" --static --disable-system --disable-libssh2
	make
fi

popd > /dev/null
popd > /dev/null

report_info "Process finished"

exit 0
