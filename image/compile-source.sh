#!/bin/bash -exu

# RED Brick Image Generator
# Copyright (C) 2014-2015 Matthias Bolte <matthias@tinkerforge.com>
# Copyright (C) 2014-2017 Ishraq Ibne Ashraf <ishraq@tinkerforge.com>
# Copyright (C) 2014 Olaf Lüke <olaf@tinkerforge.com>
#
# compile-source.sh: Compiles u-boot and kernel source code
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

# Getting the image configuration variables
if [ "$#" -ne 1 ]
then
	report_error "Too many or too few parameters (provide image configuration name)"
	exit 1
fi

CONFIG_NAME=$1
. $CONFIG_DIR/image.conf

# Checking for the build directory
if [ ! -d $BUILD_DIR ]
then
	mkdir -p $BUILD_DIR
fi

# Cleaning up .built files
rm -f $BUILD_DIR/u-boot-*.built

# Check U-Boot source directory
if [ ! -d $UBOOT_SRC_DIR/arch ]
then
	report_error "U-boot source not found"
	exit 1
fi

# Check kernel source directory
if [ ! -d $KERNEL_SRC_DIR/arch ]
then
	report_error "Kernel source not found"
	exit 1
fi

# Adding the toolchain to the subshell environment
export PATH=$TOOLS_DIR/$TC_DIR_NAME/bin:$PATH

# Building U-Boot
pushd $UBOOT_SRC_DIR > /dev/null
if [ $CLEAN_BEFORE_COMPILE == "yes" ]
then
	make ARCH=arm CROSS_COMPILE=$TC_PREFIX clean
fi
make ARCH=arm CROSS_COMPILE=$TC_PREFIX $UBOOT_CONFIG_NAME
make ARCH=arm CROSS_COMPILE=$TC_PREFIX -j16
popd > /dev/null
touch $BUILD_DIR/u-boot-$CONFIG_NAME.built

# Building the kernel
pushd $KERNEL_SRC_DIR > /dev/null
cp $KERNEL_CONFIG_FILE arch/arm/configs
cp $KERNEL_DTS_FILE arch/arm/boot/dts
if [ $CLEAN_BEFORE_COMPILE == "yes" ]
then
	make ARCH=arm CROSS_COMPILE=$TC_PREFIX LOCALVERSION="" clean
fi
rm -f ../*.tar.gz ../*.deb ../*.dsc ../*.changes
make \
ARCH=arm \
CROSS_COMPILE=$TC_PREFIX \
LOCALVERSION="" \
$KERNEL_CONFIG_NAME \
DEBFULLNAME="Ishraq Ibne Ashraf" \
DEBEMAIL="ishraq@tinkerforge.com" \
deb-pkg dtbs -j 16
popd > /dev/null
touch $BUILD_DIR/kernel-$CONFIG_NAME.built

report_process_finish

exit 0
