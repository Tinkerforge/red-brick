#! /bin/bash -exu

. ./utilities.sh

ensure_running_as_user

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

cp $KERNEL_CONFIG_FILE $KERNEL_SRC_DIR/.config
pushd $KERNEL_SRC_DIR > /dev/null
make ARCH=arm xconfig
popd > /dev/null
cp $KERNEL_SRC_DIR/.config $KERNEL_CONFIG_FILE

report_info "Process finished"

exit 0
