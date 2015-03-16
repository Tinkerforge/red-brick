#! /bin/bash -exu

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
