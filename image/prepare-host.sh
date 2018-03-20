#!/bin/bash -exu

# RED Brick Image Generator
# Copyright (C) 2014-2015 Matthias Bolte <matthias@tinkerforge.com>
# Copyright (C) 2014 Ishraq Ibne Ashraf <ishraq@tinkerforge.com>
# Copyright (C) 2014 Olaf Lüke <olaf@tinkerforge.com>
# Copyright (C) 2014 Bastian Nordmeyer <bastian@tinkerforge.com>
#
# prepare-host.sh: Installs required packages and tools for building the image
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

ensure_running_as_user

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
	tar xf ./$TC_FILE_NAME
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

QEMU_CUR_VER=$(/usr/bin/dpkg -s qemu | /bin/grep '^Version:' | grep -o -P '(?<=1:).*(?=\+)')

if ! [[ "$QEMU_MIN_VER_NO_BUILD" = "`/bin/echo -e "$QEMU_CUR_VER\n$QEMU_MIN_VER_NO_BUILD" | /usr/bin/sort -V | /usr/bin/head -n1`" ]];
then
	# Compiling qemu-arm-static
	report_info "Compiling qemu-arm-static"

	sudo apt-get build-dep -y qemu

	pushd $TOOLS_DIR > /dev/null

	if [ ! -f ./$QEMU_BASE_NAME.tar.bz2 ]
	then
		wget https://download.qemu.org/$QEMU_BASE_NAME.tar.bz2
	fi

	if [ ! -d ./$QEMU_BASE_NAME ]
	then
		tar xjf ./$QEMU_BASE_NAME.tar.bz2
	fi

	pushd ./$QEMU_BASE_NAME > /dev/null

	if [ ! -f ./arm-linux-user/qemu-arm ]
	then
		./configure --target-list="arm-linux-user" --static --disable-system
		make
	fi

	popd > /dev/null
	popd > /dev/null
fi

report_process_finish

exit 0
