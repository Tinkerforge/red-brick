#!/bin/bash -exu

# RED Brick Image Generator
# Copyright (C) 2014-2015 Matthias Bolte <matthias@tinkerforge.com>
# Copyright (C) 2014 Ishraq Ibne Ashraf <ishraq@tinkerforge.com>
#
# make-image.sh: Combines root-fs, kernel and related stuff into the final image file
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

# Cleanup function in case of interrupts
function cleanup {
	report_info "Cleaning up before exit..."

	# Unmount and release loop device
	set +e

	if [ -n "${loop_dev_p1+1}" ]
	then
		umount -f $loop_dev_p1
		losetup -d $loop_dev_p1
	fi

	if [ -n "${loop_dev+1}" ]
	then
		losetup -d $loop_dev
	fi

	set -e
}

trap "cleanup" SIGHUP SIGINT SIGTERM SIGQUIT

# Checking if root-fs was generated for the provided image configuration
if [ ! -e $BUILD_DIR/root-fs-$CONFIG_NAME.built ]
then
	report_error "Root-fs was not generated for the provided image configuration"
	exit 1
fi

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

# Checking stray /proc mount on root-fs directory
set +e
report_info "Checking stray /proc mount on root-fs directory"
if [ -d $ROOTFS_DIR/proc ]
then
	umount $ROOTFS_DIR/proc &> /dev/null
fi
set -e

# Cleaning previously built image
report_info "Cleaning previously built image"
rm -rf $OUTPUT_DIR/$IMAGE_NAME.img

# Making output directory if required
report_info "Making output directory if required"
if [ ! -d $OUTPUT_DIR ]
then
	mkdir -p $OUTPUT_DIR
fi

# Creating empty image
report_info "Creating empty image"
dd bs=$IMAGE_DD_BS count=$IMAGE_DD_COUNT if=/dev/zero | pv -treb | dd of=$IMAGE_FILE

# Setting up loop device for image
report_info "Setting up loop device for image"
loop_dev=$(losetup -f)
losetup $loop_dev $IMAGE_FILE

# Partitioning image
set +e
report_info "Partitioning the image"
fdisk $loop_dev <<EOF
o
n
p
1
$ROOT_PART_START_SECTOR

w
EOF
set -e

# Setting up loop device for image partition
report_info "Setting up loop device for image partition"
loop_dev_p1=$(losetup -f)
losetup -o $((512*$ROOT_PART_START_SECTOR)) $loop_dev_p1 $IMAGE_FILE

# Formatting image partition
report_info "Formatting image partition"
mkfs.ext3 $loop_dev_p1 -L $PARTITION_LABEL

# Installing U-Boot, boot script and the kernel to the image
report_info "Installing U-Boot to the image"
dd bs=512 seek=$UBOOT_DD_SEEK if=$UBOOT_IMAGE_FILE of=$loop_dev
report_info "Installing boot script to the image"
dd bs=512 seek=$SCRIPT_DD_SEEK if=$SCRIPT_BIN_FILE of=$loop_dev
report_info "Installing the kernel to the image"
dd bs=512 seek=$KERNEL_DD_SEEK if=$KERNEL_IMAGE_FILE of=$loop_dev

# Copying root-fs and kernel modules to the image
report_info "Copying root-fs and kernel modules to the image"
if [ ! -d $MOUNT_DIR ]
then
	mkdir -p $MOUNT_DIR
else
	rm -rf $MOUNT_DIR
	mkdir -p $MOUNT_DIR
fi
mount $loop_dev_p1 $MOUNT_DIR
$ADVCP_BIN -garp $ROOTFS_DIR/* $MOUNT_DIR/
rsync -ac --no-o --no-g $KERNEL_SRC_DIR/$KERNEL_MOD_DIR_NAME/lib/modules $MOUNT_DIR/lib/
rsync -ac --no-o --no-g $KERNEL_SRC_DIR/$KERNEL_MOD_DIR_NAME/lib/firmware $MOUNT_DIR/lib/
umount $loop_dev_p1

cleanup
report_process_finish

exit 0
