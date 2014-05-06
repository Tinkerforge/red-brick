#!/bin/bash

set -e

. ./utilities.sh

ROOT_UID="0"

# Check if running as root
if [ "$UID" -ne "$ROOT_UID" ]
then
    report_error "You must be root to execute the script"
    exit 1
fi

report_info "Installing tools"

apt-get install build-essential qemu-user-static multistrap git-core u-boot-tools

exit 0
