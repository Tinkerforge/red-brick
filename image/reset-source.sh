#! /bin/bash -exu

BASE_DIR=`pwd`
CONFIG_DIR="$BASE_DIR/config"

. ./utilities.sh
. $CONFIG_DIR/common.conf

clone_reset () {
    display_name=$1
    target_dir=$2
    git_url=$3
    git_branch=$4

    if [ ! -d $target_dir ]
    then
        report_info "Cloning $display_name source"
        git clone --depth 1 -b $git_branch $git_url $target_dir
    else
        report_info "Resetting $display_name source"
        pushd $target_dir > /dev/null
        git reset --hard origin/$git_branch
        git clean -qfx
        git pull origin $git_branch
        popd > /dev/null
    fi
}

# Clone/Reset U-Boot source
clone_reset "U-Boot" $UBOOT_SRC_DIR $UBOOT_GIT_URL $UBOOT_GIT_BRANCH

# Clone/Reset kernel source
clone_reset "kernel" $KERNEL_SRC_DIR $KERNEL_GIT_URL $KERNEL_GIT_BRANCH

# Clone/Reset sunxi-tools source
clone_reset "sunxi-tools" $SUNXI_TOOLS_SRC_DIR $SUNXI_TOOLS_GIT_URL $SUNXI_TOOLS_GIT_BRANCH

report_info "Process finished"

exit 0
