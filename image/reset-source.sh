#! /bin/bash -exu

. ./utilities.sh

clone_reset () {
    display_name=$1
    target_dir=$2
    git_url=$3
    git_branch=$4

    if [ ! -d ./$target_dir ]
    then
        report_info "Cloning $display_name source"
        git clone --depth 1 -b $git_branch $git_url ./$target_dir
    else
        report_info "Resetting $display_name source"
        pushd ./$target_dir > /dev/null
        git reset --hard origin/$git_branch
        git clean -qfx
        git pull origin $git_branch
        popd > /dev/null
    fi
}

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

# Clone/Reset U-Boot source
clone_reset "U-Boot" $UBOOT_SRC_DIR $UBOOT_GIT_URL $UBOOT_GIT_BRANCH

# Clone/Reset kernel source
clone_reset "kernel" $KERNEL_SRC_DIR $KERNEL_GIT_URL $KERNEL_GIT_BRANCH

# Clone/Reset sunxi-tools source
clone_reset "sunxi-tools" $SUNXI_TOOLS_SRC_DIR $SUNXI_TOOLS_GIT_URL $SUNXI_TOOLS_GIT_BRANCH

report_info "Process finished"

exit 0
