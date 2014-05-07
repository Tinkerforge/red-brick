#! /bin/bash -exu

. ./utilities.sh

ROOT_UID="0"

# Check if running as root
if [ "$(id -u)" -ne "$ROOT_UID" ]
then
    report_error "You must be root to execute the script"
    exit 1
fi

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

report_info "Installing tools"

apt-get install $REQUIRED_PACKAGES -y

# Installing cross compiling toolchain
report_info "Installing cross compiling toolchain"
cd ~/
if [ ! -f ./$TC_FILE_NAME ]
then
    wget $TC_DL_LINK
fi
tar $TAR_SWITCHES $TC_FILE_NAME

report_info "Process finished"

exit 0
