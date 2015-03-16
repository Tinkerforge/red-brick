#!/bin/bash -exu

# RED Brick Image Generator
# Copyright (C) 2015 Matthias Bolte <matthias@tinkerforge.com>
#
# edit-kernel-config.sh: Runs make xconfig for the kernel source code
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public
# License along with this program; if not, write to the
# Free Software Foundation, Inc., 59 Temple Place - Suite 330,
# Boston, MA 02111-1307, USA.

. ./utilities.sh

ensure_running_as_user

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

cp $KERNEL_CONFIG_FILE $KERNEL_SRC_DIR/.config
pushd $KERNEL_SRC_DIR > /dev/null
make ARCH=arm xconfig
popd > /dev/null
cp $KERNEL_SRC_DIR/.config $KERNEL_CONFIG_FILE

report_process_finish

exit 0
