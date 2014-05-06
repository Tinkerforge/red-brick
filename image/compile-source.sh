#!/bin/bash

set -e

. ./utilities.sh

# Getting the configuration variables
if [ "$#" -ne 1 ]; then
    report_error "Too many or too few parameters (provide image configuration)"
    exit 1
fi
if [ ! -e $1 ] || [ -d $1 ]; then
    report_error "No such configuration file"
    exit 1
fi
. $1

# Check U-Boot patch
if [ ! -e ./$OPTS_DIR/u-boot/$UBOOT_PATCH ]
then
    report_error "U-Boot patch not found"
    exit 1
fi
# Check kernel config
if [ ! -e ./$OPTS_DIR/kernel/$KERNEL_CONFIG ]
then
    report_error "Kernel config not found"
    exit 1
fi
# Check kernel patch
if [ ! -e ./$OPTS_DIR/kernel/$KERNEL_I2C_PATCH ]
then
    report_error "Kernel I2C patch not found"
    exit 1
fi
if [ ! -e ./$OPTS_DIR/kernel/$KERNEL_HCD_AXP_PATCH ]
then
    report_error "Kernel HCD_AXP patch not found"
    exit 1
fi
# Check boot script FEX file
if [ ! -e ./$OPTS_DIR/kernel/$KERNEL_SCRIPT_FEX ]
then
    report_error "Boot script FEX file not found"
    exit 1
fi
# Check U-Boot source directory
if [ ! -d ./$UBOOT_SRC_DIR/arch ]
then
    report_error "U-boot source not found"
    exit 1
fi
# Check kernel source directory
if [ ! -d ./$KERNEL_SRC_DIR/arch ]
then
    report_error "Kernel source not found"
    exit 1
fi
# Check sunxi-tools directory
if [ ! -d ./$TOOLS_DIR ]
then
    report_error "Sunxi-tools source not found"
    exit 1
fi

# Patching and building u-boot
cd ./$UBOOT_SRC_DIR
cp ../$OPTS_DIR/u-boot/$UBOOT_PATCH ./

patch -p1 --dry-run --silent < ./$UBOOT_PATCH>/dev/null
if [ $? -eq 0 ]
then
    patch -p1 < ./$UBOOT_PATCH
fi
make ARCH=arm CROSS_COMPILE=$CROSS_COMPILE_TC clean
make ARCH=arm CROSS_COMPILE=$CROSS_COMPILE_TC $UBOOT_CONFIG
make ARCH=arm CROSS_COMPILE=$CROSS_COMPILE_TC -j16
cd ../

# Patching and building the kernel and kernel modules
cd ./$KERNEL_SRC_DIR
cp ../$OPTS_DIR/kernel/$KERNEL_CONFIG ./arch/arm/configs

make ARCH=arm CROSS_COMPILE=$CROSS_COMPILE_TC clean
make ARCH=arm CROSS_COMPILE=$CROSS_COMPILE_TC $KERNEL_CONFIG
cp ../$OPTS_DIR/kernel/$KERNEL_I2C_PATCH ./
cp ../$OPTS_DIR/kernel/$KERNEL_HCD_AXP_PATCH ./
patch -p0 --dry-run --silent < ./$KERNEL_I2C_PATCH>/dev/null
if [ $? -eq 0 ]
then
   patch -p0 < ./$KERNEL_I2C_PATCH
fi
patch -p1 --dry-run --silent < ./$KERNEL_HCD_AXP_PATCH>/dev/null
if [ $? -eq 0 ]
then
    patch -p1 < ./$KERNEL_HCD_AXP_PATCH
fi
make ARCH=arm CROSS_COMPILE=$CROSS_COMPILE_TC -j16 INSTALL_MOD_PATH=$KERNEL_MOD_DIR $KERNEL_IMAGE modules
make ARCH=arm CROSS_COMPILE=$CROSS_COMPILE_TC INSTALL_MOD_PATH=$KERNEL_MOD_DIR modules_install
cd ../

# Building sunxi-tools
cd ./$SUNXI_TOOLS_DIR
make clean
make all
./fex2bin ../$OPTS_DIR/kernel/$KERNEL_SCRIPT_FEX ../$OPTS_DIR/kernel/$KERNEL_SCRIPT_BIN

sync

report_info "Process finished"

exit 0
