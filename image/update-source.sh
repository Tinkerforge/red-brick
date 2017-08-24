#!/bin/bash -exu

# RED Brick Image Generator
# Copyright (C) 2014-2015 Matthias Bolte <matthias@tinkerforge.com>
# Copyright (C) 2017 Ishraq Ibne Ashraf <ishraq@tinkerforge.com>
#
# update-source.sh: Updates/Clones kernel and related git repositories
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

update () {
	display_name=$1
	target_dir=$2
	git_url=$3
	git_branch=$4

	if [ ! -d $target_dir ]
	then
		report_info "Cloning $display_name source"
		git clone --depth 1 -b $git_branch $git_url $target_dir
	else
		report_info "Clone of $display_name source already exists, updating it"
		pushd $target_dir > /dev/null
		git pull origin $git_branch
		popd > /dev/null
	fi
}

# Clone/Pull U-Boot source
update "U-Boot" $UBOOT_SRC_DIR $UBOOT_GIT_URL $UBOOT_GIT_BRANCH

# Clone/Pull kernel source
update "kernel" $KERNEL_SRC_DIR $KERNEL_GIT_URL $KERNEL_GIT_BRANCH

report_process_finish

exit 0
