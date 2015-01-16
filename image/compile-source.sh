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

# Cleaning up boot script file
rm -rf $SCRIPT_BIN_FILE

# Checking for the build directory
if [ ! -d $BUILD_DIR ]
then
	mkdir -p $BUILD_DIR
fi

# Cleaning up .built files
rm -f $BUILD_DIR/u-boot-*.built
rm -f $BUILD_DIR/kernel-*.built
rm -f $BUILD_DIR/kernel-headers-*.built

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
if [ $CLEAN_BEFORE_COMPILE == "yes" ]
then
	make ARCH=arm CROSS_COMPILE=$TC_PREFIX clean
fi
make ARCH=arm CROSS_COMPILE=$TC_PREFIX $UBOOT_CONFIG_NAME
# set GAS_BUG_12532 to n. we use gas 2.23, the bug was fixed in 2.22, but due to the
# managed version output of our gas the version detection in the Makefile fails and
# we have to force the correct result
make ARCH=arm CROSS_COMPILE=$TC_PREFIX GAS_BUG_12532=n -j16
popd > /dev/null
touch $BUILD_DIR/u-boot-$CONFIG_NAME.built

# Building the kernel and kernel modules
pushd $KERNEL_SRC_DIR > /dev/null
cp $KERNEL_CONFIG_FILE ./arch/arm/configs
make ARCH=arm CROSS_COMPILE=$TC_PREFIX $KERNEL_CONFIG_NAME
if [ $CLEAN_BEFORE_COMPILE == "yes" ]
then
    make ARCH=arm CROSS_COMPILE=$TC_PREFIX clean
fi
make ARCH=arm CROSS_COMPILE=$TC_PREFIX -j16 INSTALL_MOD_PATH=$KERNEL_MOD_DIR_NAME $KERNEL_IMAGE_NAME modules
make ARCH=arm CROSS_COMPILE=$TC_PREFIX INSTALL_MOD_PATH=$KERNEL_MOD_DIR_NAME modules_install
make ARCH=arm CROSS_COMPILE=$TC_PREFIX headers_install
popd > /dev/null
touch $BUILD_DIR/kernel-$CONFIG_NAME.built
touch $BUILD_DIR/kernel-headers-$CONFIG_NAME.built

# Building sunxi-tools
pushd $SUNXI_TOOLS_SRC_DIR > /dev/null
if [ $CLEAN_BEFORE_COMPILE == "yes" ]
then
	make clean
fi
make all
./fex2bin $SCRIPT_FEX_FILE $SCRIPT_BIN_FILE
popd > /dev/null

report_info "Process finished"

exit 0
