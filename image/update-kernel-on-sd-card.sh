#!/bin/bash -exu

# RED Brick Image Generator
# Copyright (C) 2014-2015 Matthias Bolte <matthias@tinkerforge.com>
# Copyright (C) 2014 Ishraq Ibne Ashraf <ishraq@tinkerforge.com>
# Copyright (C) 2014 Olaf Lüke <olaf@tinkerforge.com>
#
# update-kernel-on-sd-card.sh: Writes new kernel and related stuff to an SD card
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
if [ "$#" -ne 2 ]; then
	report_error "Too many or too few parameters (provide image configuration name and device)"
	exit 1
fi

CONFIG_NAME=$1
DEVICE=$2
. $CONFIG_DIR/image.conf

# Cleanup function in case of interrupts
function cleanup {
	report_info "Cleaning up before exit..."

	# Checking stray mounts
	set +e

	if [ -d $MOUNT_DIR ]
	then
		umount -f $MOUNT_DIR
	fi

	set -e
}

trap "cleanup" SIGHUP SIGINT SIGTERM SIGQUIT EXIT

# Checking image file
if [ ! -e $KERNEL_IMAGE_FILE ]
then
	report_error "Please build kernel first"
	exit 1
fi

# Checking device
if [ ! -e $DEVICE ]
then
	report_error "SD card does not exist"
	exit 1
fi

# Copying u-boot image to the SD card
report_info "Copying u-boot image to the SD card"
dd bs=1024 seek=$UBOOT_DD_SEEK if=$UBOOT_IMAGE_FILE of=$DEVICE

# Copying script bin to the SD card
#report_info "Copying script bin to the SD card"
#dd bs=512 seek=$SCRIPT_DD_SEEK if=$SCRIPT_BIN_FILE of=$DEVICE

# Copying kernel image and the DTB to the SD card
report_info "Copying kernel image and the DTB to the SD card"
#dd bs=512 seek=$KERNEL_DD_SEEK if=$KERNEL_IMAGE_FILE of=$DEVICE

if [ -d $MOUNT_DIR ]
then
	rm -rf $MOUNT_DIR
	mkdir -p $MOUNT_DIR
else
	mkdir -p $MOUNT_DIR
fi
mount -t ext3 -o offset=$((512*$ROOT_PART_START_SECTOR)) $DEVICE $MOUNT_DIR
cp $KERNEL_IMAGE_FILE $MOUNT_DIR/boot/kernel
cp $KERNEL_DTB_FILE $MOUNT_DIR/boot/kernel/dtb
cp $UBOOT_BOOT_CMD_FILE $MOUNT_DIR/boot
$UBOOT_SRC_DIR/tools/mkimage -C none -A arm -T script -d $MOUNT_DIR/boot/boot.cmd $MOUNT_DIR/boot/boot.scr

# Copying kernel headers to the SD card
report_info "Copying kernel headers to the SD card"
rsync -ac --no-o --no-g $KERNEL_HEADER_INCLUDE_DIR $MOUNT_DIR/usr/
rsync -ac --no-o --no-g $KERNEL_HEADER_USR_DIR $MOUNT_DIR

# Copying kernel modules to the SD card
report_info "Copying kernel modules to the SD card"
rm -rf $MOUNT_DIR/lib/modules
rsync -ac --no-o --no-g $KERNEL_SRC_DIR/$KERNEL_MOD_DIR_NAME/lib/modules $MOUNT_DIR/lib/
rsync -ac --no-o --no-g $KERNEL_SRC_DIR/$KERNEL_MOD_DIR_NAME/lib/firmware $MOUNT_DIR/lib/

trap - SIGHUP SIGINT SIGTERM SIGQUIT EXIT
cleanup
report_process_finish

exit 0
