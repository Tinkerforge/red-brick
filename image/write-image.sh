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
if [ ! -e $IMAGE_FILE ]
then
    report_error "Please build image first"
    exit 1
fi

# Checking device
if [ ! -e $DEVICE ]
then
    report_error "Device does not exist"
    exit 1
fi

pv -tpreb $IMAGE_FILE | dd of=$DEVICE bs=64M
