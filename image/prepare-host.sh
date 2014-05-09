#! /bin/bash -exu

. ./utilities.sh

BASE_DIR=`pwd`
CONFIG_DIR="$BASE_DIR/config"

. $CONFIG_DIR/common.conf

# Installing tools
report_info "Installing tools (requires root access)"

sudo apt-get install -y $REQUIRED_HOST_PACKAGES

# Installing cross compiling toolchain
report_info "Installing cross compiling toolchain"

if [ ! -d $TOOLS_DIR ]
then
    mkdir -p $TOOLS_DIR
fi

pushd $TOOLS_DIR > /dev/null

if [ ! -f ./$TC_FILE_NAME ]
then
    wget $TC_URL
fi

if [ ! -d ./$TC_DIR_NAME ]
then
    tar jxf ./$TC_FILE_NAME
fi

popd > /dev/null

report_info "Process finished"

exit 0
