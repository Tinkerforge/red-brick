#! /bin/bash -exu

. ./utilities.sh

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

# Patching U-Boot
pushd $UBOOT_SRC_DIR > /dev/null
xargs -d '\n' -I {} -a $PATCHES_DIR/u-boot/$CONFIG_NAME.series patch -p1 -r - -i $PATCHES_DIR/u-boot/{}
popd > /dev/null

# Patching and configureing the kernel and kernel modules
pushd $KERNEL_SRC_DIR > /dev/null
cp $KERNEL_CONFIG_FILE ./arch/arm/configs
make ARCH=arm CROSS_COMPILE=$TC_PREFIX $KERNEL_CONFIG_NAME
xargs -d '\n' -I {} -a $PATCHES_DIR/kernel/$CONFIG_NAME.series patch -p1 -r - -i $PATCHES_DIR/kernel/{}
popd > /dev/null

report_info "Process finished"

exit 0
