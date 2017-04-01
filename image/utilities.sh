#!/bin/bash

# RED Brick Image Generator
# Copyright (C) 2014-2015 Matthias Bolte <matthias@tinkerforge.com>
# Copyright (C) 2014 Ishraq Ibne Ashraf <ishraq@tinkerforge.com>
#
# utilities.sh: Utility functions for other scripts
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

PROCESS_START_DATE=`date '+%Y-%m-%d %H:%M:%S'`

report_error () {
	echo -e "\n`date '+%Y-%m-%d %H:%M:%S'` - Error: $1\n"
}

report_info () {
	echo -e "\n`date '+%Y-%m-%d %H:%M:%S'` - Info: $1\n"
}

report_process_finish () {
	report_info "Process finished (started $PROCESS_START_DATE)"
}

ensure_running_as_root () {
	if [ "$(id -u)" -ne "0" ]
	then
		report_error "Script must be executed as root, try again with sudo"
		exit 1
	fi
}

ensure_running_as_user () {
	if [ "$(id -u)" -eq "0" ]
	then
		report_error "Script must NOT be executed as root, try again without sudo"
		exit 1
	fi
}

filter_kernel_source () {
	rm -rf .git* output modules CREDITS MAINTAINERS REPORTING-BUGS
}
