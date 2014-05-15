#! /bin/bash -exu

. ./utilities.sh

BASE_DIR=`pwd`
CONFIG_DIR="$BASE_DIR/config"

. $CONFIG_DIR/common.conf

clone () {
    display_name=$1
    target_dir=$2
    git_url=$3
    git_branch=$4

    if [ ! -d $target_dir ]
    then
        report_info "Cloning $display_name source"
        git clone --depth 1 -b $git_branch $git_url $target_dir
    else
        report_info "Clone of $display_name source already exists, doing nothing"
    fi
}

# Clone/Reset U-Boot source
clone "U-Boot" $UBOOT_SRC_DIR $UBOOT_GIT_URL $UBOOT_GIT_BRANCH

# Clone/Reset kernel source
clone "kernel" $KERNEL_SRC_DIR $KERNEL_GIT_URL $KERNEL_GIT_BRANCH

# Clone/Reset sunxi-tools source
clone "sunxi-tools" $SUNXI_TOOLS_SRC_DIR $SUNXI_TOOLS_GIT_URL $SUNXI_TOOLS_GIT_BRANCH

report_info "Process finished"

exit 0
