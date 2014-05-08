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

# Check U-Boot patch
if [ ! -e $PATCHES_DIR/u-boot/$UBOOT_PATCH ]
then
    report_error "U-Boot patch not found"
    exit 1
fi
# Check kernel config
if [ ! -e $PATCHES_DIR/kernel/$KERNEL_CONFIG ]
then
    report_error "Kernel config not found"
    exit 1
fi
# Check kernel patch
if [ ! -e $PATCHES_DIR/kernel/$KERNEL_I2C_PATCH ]
then
    report_error "Kernel I2C patch not found"
    exit 1
fi
if [ ! -e $PATCHES_DIR/kernel/$KERNEL_HCD_AXP_PATCH ]
then
    report_error "Kernel HCD_AXP patch not found"
    exit 1
fi
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

# Patching and building U-Boot
pushd $UBOOT_SRC_DIR > /dev/null
cp $PATCHES_DIR/u-boot/$UBOOT_PATCH ./
patch -p1 --dry-run --silent < ./$UBOOT_PATCH > /dev/null
if [ $? -eq 0 ]
then
    patch -p1 < ./$UBOOT_PATCH
fi
make ARCH=arm CROSS_COMPILE=$TC_PREFIX clean
make ARCH=arm CROSS_COMPILE=$TC_PREFIX $UBOOT_CONFIG
make ARCH=arm CROSS_COMPILE=$TC_PREFIX -j16
popd > /dev/null

# Patching and building the kernel and kernel modules
pushd $KERNEL_SRC_DIR > /dev/null
cp $PATCHES_DIR/kernel/$KERNEL_CONFIG ./arch/arm/configs
make ARCH=arm CROSS_COMPILE=$TC_PREFIX clean
make ARCH=arm CROSS_COMPILE=$TC_PREFIX $KERNEL_CONFIG
cp $PATCHES_DIR/kernel/$KERNEL_I2C_PATCH ./
cp $PATCHES_DIR/kernel/$KERNEL_HCD_AXP_PATCH ./
patch -p0 --dry-run --silent < ./$KERNEL_I2C_PATCH > /dev/null
if [ $? -eq 0 ]
then
   patch -p0 < ./$KERNEL_I2C_PATCH
fi
patch -p1 --dry-run --silent < ./$KERNEL_HCD_AXP_PATCH > /dev/null
if [ $? -eq 0 ]
then
    patch -p1 < ./$KERNEL_HCD_AXP_PATCH
fi
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
