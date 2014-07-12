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

# Copying the kernel to the SD card
report_info "Copying U-Boot bin to the SD card"
dd bs=512 seek=$UBOOT_DD_SEEK if=$UBOOT_IMAGE_FILE of=$DEVICE
report_info "Copying the fex bin to the SD card"
dd bs=512 seek=$SCRIPT_DD_SEEK if=$SCRIPT_BIN_FILE of=$DEVICE
report_info "Copying the kernel to the SD card"
dd bs=512 seek=$KERNEL_DD_SEEK if=$KERNEL_IMAGE_FILE of=$DEVICE

# Copying kernel modules to the SD card
report_info "Copying kernel modules to the SD card"
mkdir -p $MOUNT_DIR
mount -t ext3 -o offset=$((512*$ROOT_PART_START_SECTOR)) $DEVICE $MOUNT_DIR
rsync -arpc $KERNEL_SRC_DIR/$KERNEL_MOD_DIR_NAME/lib/modules $MOUNT_DIR/lib/
rsync -arpc $KERNEL_SRC_DIR/$KERNEL_MOD_DIR_NAME/lib/firmware $MOUNT_DIR/lib/
umount $MOUNT_DIR

report_info "Process finished"

exit 0
