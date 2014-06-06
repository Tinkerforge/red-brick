#! /bin/bash -exu

. ./utilities.sh
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

mkdir -p $APTCACHER_DIR/cache-3
mkdir -p $APTCACHER_DIR/log-3

if [ `netstat -lnt | awk '$6 == "LISTEN" && $4 ~ ".3153"' | wc -l` -eq 0 ]
then
	apt-cacher -d -c $CONFIG_DIR/apt-cacher.conf -p $APTCACHER_DIR/pid-3 cache_dir=$APTCACHER_DIR/cache-3 log_dir=$APTCACHER_DIR/log-3 daemon_port=3153
fi

report_info "Process finished"

exit 0
