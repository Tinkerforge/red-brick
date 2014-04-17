#! /bin/bash

# Variables
CROSS_COMPILE_TC="arm-linux-gnueabihf-"
OPTS_DIR="optimizations"

UBOOT_SRC_DIR="u-boot-sunxi"
UBOOT_CONFIG="A10s-OLinuXino-M_config"
UBOOT_PATCH="u-boot-opt-spl-ramoc.patch"

KERNEL_SRC_DIR="linux-sunxi"
KERNEL_CONFIG="red_brick_full_defconfig"
KERNEL_I2C_PATCH="sunxi-i2c.patch"
KERNEL_HCD_AXP_PATCH="hcd_axp.patch"
KERNEL_IMAGE="uImage"
KERNEL_MOD_PATH="out"

SUNXI_TOOLS_DIR="sunxi-tools"
SCRIPT_FEX="script_red_brick.fex"
SCRIPT_BIN="script_red_brick.bin"

# Check U_Boot patch
if [ ! -e ./$OPTS_DIR/u-boot/$UBOOT_PATCH ]
then
    echo -e "\nError: U-Boot patch not found\n"
    exit 1
fi
# Check kernel config
if [ ! -e ./$OPTS_DIR/kernel/$KERNEL_CONFIG ]
then
    echo -e "\nError: Kernel config not found\n"
    exit 1
fi
# Check kernel patch
if [ ! -e ./$OPTS_DIR/kernel/$KERNEL_I2C_PATCH ]
then
    echo -e "\nError: Kernel I2C patch not found\n"
    exit 1
fi
if [ ! -e ./$OPTS_DIR/kernel/$KERNEL_HCD_AXP_PATCH ]
then
    echo -e "\nError: Kernel HCD_AXP patch not found\n"
    exit 1
fi
# Check boot script FEX file
if [ ! -e ./$OPTS_DIR/kernel/$SCRIPT_FEX ]
then
    echo -e "\nError: Boot script FEX file not found\n"
    exit 1
fi
# Check U-Boot source directory
if [ ! -d ./$UBOOT_SRC_DIR/arch ]
then
    echo -e "\nError: U-boot source not found\n"
    exit 1
fi
# Check kernel source directory
if [ ! -d ./$KERNEL_SRC_DIR/arch ]
then
    echo -e "\nError: Kernel source not found\n"
    exit 1
fi
# Check sunxi-tools directory
if [ ! -d ./$TOOLS_DIR ]
then
    echo -e "\nError: Sunxi-tools source not found\n"
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
make ARCH=arm CROSS_COMPILE=$CROSS_COMPILE_TC -j16 INSTALL_MOD_PATH=$KERNEL_MOD_PATH $KERNEL_IMAGE modules
make ARCH=arm CROSS_COMPILE=$CROSS_COMPILE_TC INSTALL_MOD_PATH=$KERNEL_MOD_PATH modules_install
cd ../

# Building sunxi-tools
cd ./$SUNXI_TOOLS_DIR
make clean
make all
./fex2bin ../$OPTS_DIR/kernel/$SCRIPT_FEX ../$OPTS_DIR/kernel/$SCRIPT_BIN

sync

exit 0
