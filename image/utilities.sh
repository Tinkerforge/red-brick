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
	find . -type f -name "*.txt" -exec rm -- {} \;
	find . -type f -name .gitignore -exec rm -- {} \;
	find . -type f -name COPYING -exec rm -- {} \;
	find . -type f -name "*.README" -exec rm -- {} \;
	find . -type f -name "README.*" -exec rm -- {} \;
	find . -type f -name README -exec rm -- {} \;
	find . -type f -name TODO -exec rm -- {} \;
	find arch -type f -name "*.c" -exec rm -- {} \;
	find arch -type f -name "*.S" -exec rm -- {} \;
	find arch -type f -name "*_defconfig" -exec rm -- {} \;
	find block -type f -name "*.c" -exec rm -- {} \;
	find block -type f -name "*.h" -exec rm -- {} \;
	find crypto -type f -name "*.c" -exec rm -- {} \;
	find crypto -type f -name "*.h" -exec rm -- {} \;
	find Documentation -type f -name "*.c" -exec rm -- {} \;
	find Documentation -type f -name "*.b64" -exec rm -- {} \;
	find Documentation -type f -name "*.dot" -exec rm -- {} \;
	find Documentation -type f -name "*.pdf" -exec rm -- {} \;
	find Documentation -type f -name "*.svg" -exec rm -- {} \;
	find Documentation -type f -name "*.tmpl" -exec rm -- {} \;
	find Documentation -type f -name "*.xml" -exec rm -- {} \;
	find Documentation -type f -name 00-INDEX -exec rm -- {} \;
	find drivers -type f -name "*.c" -exec rm -- {} \;
	find drivers -type f -name "*.h" -exec rm -- {} \;
	find drivers -type f -name "*.c_shipped" -exec rm -- {} \;
	find drivers -type f -name "*.h_shipped" -exec rm -- {} \;
	find drivers -type f -name "*.S" -exec rm -- {} \;
	find firmware -type f -name "*.c" -exec rm -- {} \;
	find firmware -type f -name "*.S" -exec rm -- {} \;
	find firmware -type f -name "*.H16" -exec rm -- {} \;
	find firmware -type f -name "*.HEX" -exec rm -- {} \;
	find firmware -type f -name "*.ihex" -exec rm -- {} \;
	find fs -type f -name "*.c" -exec rm -- {} \;
	find fs -type f -name "*.h" -exec rm -- {} \;
	find init -type f -name "*.c" -exec rm -- {} \;
	find init -type f -name "*.h" -exec rm -- {} \;
	find ipc -type f -name "*.c" -exec rm -- {} \;
	find ipc -type f -name "*.h" -exec rm -- {} \;
	find kernel -type f -name "*.c" -exec rm -- {} \;
	find kernel -type f -name "*.h" -exec rm -- {} \;
	find lib -type f -name "*.c" -exec rm -- {} \;
	find lib -type f -name "*.h" -exec rm -- {} \;
	find mm -type f -name "*.c" -exec rm -- {} \;
	find net -type f -name "*.c" -exec rm -- {} \;
	find net -type f -name "*.h" -exec rm -- {} \;
	find samples -type f -name "*.c" -exec rm -- {} \;
	find samples -type f -name "*.h" -exec rm -- {} \;
	find security -type f -name "*.c" -exec rm -- {} \;
	find security -type f -name "*.h" -exec rm -- {} \;
	find sound -type f -name "*.c" -exec rm -- {} \;
	find sound -type f -name "*.h" -exec rm -- {} \;
	find tools -type f -name "*.c" -exec rm -- {} \;
	find tools -type f -name "*.h" -exec rm -- {} \;
	find usr -type f -name "*.c" -exec rm -- {} \;
	find usr -type f -name "*.S" -exec rm -- {} \;
	find virt -type f -name "*.c" -exec rm -- {} \;
	find virt -type f -name "*.h" -exec rm -- {} \;
}
