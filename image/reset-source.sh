#!/bin/bash

# Variables
UBOOT_SRC_DIR="u-boot-sunxi"
UBOOT_GIT_BRANCH="sunxi"
UBOOT_GIT_SRC="http://github.com/linux-sunxi/u-boot-sunxi.git"

KERNEL_SRC_DIR="linux-sunxi"
KERNEL_GIT_BRANCH="sunxi-3.4"
KERNEL_GIT_SRC="http://github.com/linux-sunxi/linux-sunxi.git"

SUNXI_TOOLS_SRC_DIR="sunxi-tools"
SUNXI_TOOLS_GIT_SRC="http://github.com/linux-sunxi/sunxi-tools.git"

# Reset U-Boot source
echo -e "\nInfo: Reset U-Boot source\n"
if [ -d ./$UBOOT_SRC_DIR ]
then
    rm -vfr ./$UBOOT_SRC_DIR
fi
git clone -b $UBOOT_GIT_BRANCH $UBOOT_GIT_SRC

# Reset kernel source
echo -e "\nInfo: Reset kernel source\n"
if [ -d ./$KERNEL_SRC_DIR ]
then
    rm -vfr ./$KERNEL_SRC_DIR
fi
git clone -b $KERNEL_GIT_BRANCH $KERNEL_GIT_SRC

# Reset sunxi-tools source
echo -e "\nInfo: Reset sunxi-tools source\n"
if [ -d ./$SUNXI_TOOLS_SRC_DIR ]
then
    rm -vfr ./$SUNXI_TOOLS_SRC_DIR
fi
git clone $SUNXI_TOOLS_GIT_SRC

sync

exit 0
