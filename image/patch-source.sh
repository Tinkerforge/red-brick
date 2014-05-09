#! /bin/bash -exu

BASE_DIR=`pwd`
CONFIG_DIR="$BASE_DIR/config"

. ./utilities.sh
. $CONFIG_DIR/common.conf

# Getting the image configuration variables
if [ "$#" -ne 1 ]; then
    report_error "Too many or too few parameters (provide image configuration name)"
    exit 1
fi
if [ ! -f "$CONFIG_DIR/image_$1.conf" ]; then
    report_error "No such image configuration"
    exit 1
fi

CONFIG_NAME=$1

. $CONFIG_DIR/image_$CONFIG_NAME.conf

# Check kernel config
if [ ! -e $PATCHES_DIR/kernel/$KERNEL_CONFIG ]
then
    report_error "Kernel config not found"
    exit 1
fi

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
xargs -d '\n' -I {} -a $PATCHES_DIR/u-boot/image_$CONFIG_NAME.series patch -p1 -r - -i $PATCHES_DIR/u-boot/{}
popd > /dev/null

# Patching and configureing the kernel and kernel modules
pushd $KERNEL_SRC_DIR > /dev/null
cp $PATCHES_DIR/kernel/$KERNEL_CONFIG ./arch/arm/configs
make ARCH=arm CROSS_COMPILE=$TC_PREFIX $KERNEL_CONFIG
xargs -d '\n' -I {} -a $PATCHES_DIR/kernel/image_$CONFIG_NAME.series patch -p1 -r - -i $PATCHES_DIR/kernel/{}
popd > /dev/null

report_info "Process finished"

exit 0
