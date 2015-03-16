#!/bin/bash -exu

# RED Brick Image Generator
# Copyright (C) 2014-2015 Matthias Bolte <matthias@tinkerforge.com>
# Copyright (C) 2014 Ishraq Ibne Ashraf <ishraq@tinkerforge.com>
#
# write-image-to-sd-card.sh: Writes finished image file to an SD card
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

ensure_running_as_root

BASE_DIR=`pwd`
CONFIG_DIR="$BASE_DIR/config"
. $CONFIG_DIR/common.conf

# Getting the image configuration variables
if [ "$#" -ne 2 ]; then
	report_error "Too many or too few parameters (provide image configuration name and device)"
	exit 1
fi

CONFIG_NAME=$1
DEVICE=$2
. $CONFIG_DIR/image.conf

# Checking image file
if [ ! -e $IMAGE_FILE ]
then
	report_error "Please build image first"
	exit 1
fi

# Checking device
if [ ! -e $DEVICE ]
then
	report_error "SD card does not exist"
	exit 1
fi

# Writing image to the SD card
report_info "Writing image to the SD card"

pv -tpreb $IMAGE_FILE | dd of=$DEVICE bs=64M

report_process_finish

exit 0
