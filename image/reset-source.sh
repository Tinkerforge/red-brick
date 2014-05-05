#!/bin/bash

set -e

# Getting the configuration variables
if [ "$#" -ne 1 ]; then
    echo -e "\nError: Too many or too few parameters (provide image configuration)\n"
    exit 1
fi
if [ ! -e $1 ] || [ -d $1 ]; then
    echo -e "\nError: No such configuration file\n"
    exit 1
fi
. $1

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
