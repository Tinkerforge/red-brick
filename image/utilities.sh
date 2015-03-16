#!/bin/bash

report_error () {
	echo -e "\n`date '+%Y-%m-%d %H:%M:%S'` - Error: $1\n"
}

report_info () {
	echo -e "\n`date '+%Y-%m-%d %H:%M:%S'` - Info: $1\n"
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
