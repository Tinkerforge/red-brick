#! /bin/bash -exu

BASE_DIR=`pwd`

. ./utilities.sh
. ./config/common.conf

# Installing tools
report_info "Installing tools (requires root access)"

sudo apt-get install $REQUIRED_PACKAGES -y

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
