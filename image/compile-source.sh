#! /bin/bash -exu

BASE_DIR=`pwd`

. ./utilities.sh
. ./config/common.conf

# Getting the image configuration variables
if [ "$#" -ne 1 ]; then
    report_error "Too many or too few parameters (provide image configuration name)"
    exit 1
fi
if [ ! -f "./config/image_$1.conf" ]; then
    report_error "No such image configuration"
    exit 1
fi
. ./config/image_$1.conf


# Check boot script FEX file
if [ ! -e $PATCHES_DIR/kernel/$KERNEL_SCRIPT_FEX ]
then
    report_error "Boot script FEX file not found"
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

# Check sunxi-tools directory
if [ ! -d $SUNXI_TOOLS_SRC_DIR ]
then
    report_error "Sunxi-tools source not found"
    exit 1
fi

# Adding the toolchain to the subshell environment
export PATH=$TOOLS_DIR/$TC_DIR_NAME/bin:$PATH

# Building U-Boot
pushd $UBOOT_SRC_DIR > /dev/null
make ARCH=arm CROSS_COMPILE=$TC_PREFIX clean
make ARCH=arm CROSS_COMPILE=$TC_PREFIX $UBOOT_CONFIG
make ARCH=arm CROSS_COMPILE=$TC_PREFIX -j16
popd > /dev/null

# Building the kernel and kernel modules
pushd $KERNEL_SRC_DIR > /dev/null
make ARCH=arm CROSS_COMPILE=$TC_PREFIX clean
make ARCH=arm CROSS_COMPILE=$TC_PREFIX -j16 INSTALL_MOD_PATH=$KERNEL_MOD_DIR_NAME $KERNEL_IMAGE modules
make ARCH=arm CROSS_COMPILE=$TC_PREFIX INSTALL_MOD_PATH=$KERNEL_MOD_DIR_NAME modules_install
popd > /dev/null

# Building sunxi-tools
pushd $SUNXI_TOOLS_SRC_DIR > /dev/null
make clean
make all
./fex2bin $PATCHES_DIR/kernel/$KERNEL_SCRIPT_FEX $PATCHES_DIR/kernel/$KERNEL_SCRIPT_BIN
popd > /dev/null

report_info "Process finished"

exit 0
