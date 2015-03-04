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

trap "cleanup" SIGHUP SIGINT SIGTERM SIGQUIT

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
dd bs=512 seek=$UBOOT_DD_SEEK if=$UBOOT_IMAGE_FILE of=$DEVICE

# Copying script bin to the SD card
report_info "Copying script bin to the SD card"
dd bs=512 seek=$SCRIPT_DD_SEEK if=$SCRIPT_BIN_FILE of=$DEVICE

# Copying kernel image to the SD card
report_info "Copying kernel image to the SD card"
dd bs=512 seek=$KERNEL_DD_SEEK if=$KERNEL_IMAGE_FILE of=$DEVICE

if [ -d $MOUNT_DIR ]
then
	rm -rf $MOUNT_DIR
	mkdir -p $MOUNT_DIR
else
	mkdir -p $MOUNT_DIR
fi
mount -t ext3 -o offset=$((512*$ROOT_PART_START_SECTOR)) $DEVICE $MOUNT_DIR

# Copying kernel headers to the SD card
report_info "Copying kernel headers to the SD card"
rsync -ac --no-o --no-g $KERNEL_HEADER_INCLUDE_DIR $MOUNT_DIR/usr/
rsync -ac --no-o --no-g $KERNEL_HEADER_USR_DIR $MOUNT_DIR

# Copying kernel modules to the SD card
report_info "Copying kernel modules to the SD card"
rsync -ac --no-o --no-g $KERNEL_SRC_DIR/$KERNEL_MOD_DIR_NAME/lib/modules $MOUNT_DIR/lib/
rsync -ac --no-o --no-g $KERNEL_SRC_DIR/$KERNEL_MOD_DIR_NAME/lib/firmware $MOUNT_DIR/lib/

umount $MOUNT_DIR

cleanup
report_info "Process finished"

exit 0
