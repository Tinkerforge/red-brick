#!/bin/bash -exu

# RED Brick Image Generator
# Copyright (C) 2014-2015 Matthias Bolte <matthias@tinkerforge.com>
#
# start-apt-cacher.sh: Starts APT cacher deamons
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

report_info "Starting apt-cacher daemons"

# Some systems like Debian dont have /usr/sbin in normal user's PATH
PATH=/usr/sbin:$PATH

mkdir -p $APTCACHER_DIR/cache-0
mkdir -p $APTCACHER_DIR/log-0

if [ `netstat -lnt | awk '$6 == "LISTEN" && $4 ~ ".3150"' | wc -l` -eq 0 ]
then
	apt-cacher -d -c $CONFIG_DIR/apt-cacher.conf -p $APTCACHER_DIR/pid-0 cache_dir=$APTCACHER_DIR/cache-0 log_dir=$APTCACHER_DIR/log-0 daemon_port=3150
fi

mkdir -p $APTCACHER_DIR/cache-1
mkdir -p $APTCACHER_DIR/log-1

if [ `netstat -lnt | awk '$6 == "LISTEN" && $4 ~ ".3151"' | wc -l` -eq 0 ]
then
	apt-cacher -d -c $CONFIG_DIR/apt-cacher.conf -p $APTCACHER_DIR/pid-1 cache_dir=$APTCACHER_DIR/cache-1 log_dir=$APTCACHER_DIR/log-1 daemon_port=3151
fi

mkdir -p $APTCACHER_DIR/cache-2
mkdir -p $APTCACHER_DIR/log-2

if [ `netstat -lnt | awk '$6 == "LISTEN" && $4 ~ ".3152"' | wc -l` -eq 0 ]
then
	apt-cacher -d -c $CONFIG_DIR/apt-cacher.conf -p $APTCACHER_DIR/pid-2 cache_dir=$APTCACHER_DIR/cache-2 log_dir=$APTCACHER_DIR/log-2 daemon_port=3152
fi

report_process_finish

exit 0
