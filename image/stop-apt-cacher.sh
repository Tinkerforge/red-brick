#!/bin/bash -exu

# RED Brick Image Generator
# Copyright (C) 2014-2015 Matthias Bolte <matthias@tinkerforge.com>
#
# stop-apt-cacher.sh: Stops running APT cacher deamons
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

report_info "Stopping apt-cacher daemons"

if [ -f $APTCACHER_DIR/pid-0 ]
then
	if [ `netstat -lnt | awk '$6 == "LISTEN" && $4 ~ ".3150"' | wc -l` -ne 0 ]
	then
		kill `cat $APTCACHER_DIR/pid-0`
	fi

	rm $APTCACHER_DIR/pid-0
fi

if [ -f $APTCACHER_DIR/pid-1 ]
then
	if [ `netstat -lnt | awk '$6 == "LISTEN" && $4 ~ ".3151"' | wc -l` -ne 0 ]
	then
		kill `cat $APTCACHER_DIR/pid-1`
	fi

	rm $APTCACHER_DIR/pid-1
fi

if [ -f $APTCACHER_DIR/pid-2 ]
then
	if [ `netstat -lnt | awk '$6 == "LISTEN" && $4 ~ ".3152"' | wc -l` -ne 0 ]
	then
		kill `cat $APTCACHER_DIR/pid-2`
	fi

	rm $APTCACHER_DIR/pid-2
fi

report_process_finish

exit 0
