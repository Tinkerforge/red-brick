#! /bin/bash -exu

. ./utilities.sh
BASE_DIR=`pwd`
CONFIG_DIR="$BASE_DIR/config"

. $CONFIG_DIR/common.conf

report_info "Stopping apt-cacher daemons"

if [ -f $APTCACHER_DIR/pid-0 ]
then
	r=`netstat -lnt | awk '$6 == "LISTEN" && $4 ~ ".3150"'`

	if [ -n "$r" ]
	then
		kill `cat $APTCACHER_DIR/pid-0`
	fi

	rm $APTCACHER_DIR/pid-0
fi

if [ -f $APTCACHER_DIR/pid-1 ]
then
	r=`netstat -lnt | awk '$6 == "LISTEN" && $4 ~ ".3151"'`

	if [ -n "$r" ]
	then
		kill `cat $APTCACHER_DIR/pid-1`
	fi

	rm $APTCACHER_DIR/pid-1
fi

if [ -f $APTCACHER_DIR/pid-2 ]
then
	r=`netstat -lnt | awk '$6 == "LISTEN" && $4 ~ ".3152"'`

	if [ -n "$r" ]
	then
		kill `cat $APTCACHER_DIR/pid-2`
	fi

	rm $APTCACHER_DIR/pid-2
fi

if [ -f $APTCACHER_DIR/pid-3 ]
then
	r=`netstat -lnt | awk '$6 == "LISTEN" && $4 ~ ".3153"'`

	if [ -n "$r" ]
	then
		kill `cat $APTCACHER_DIR/pid-3`
	fi

	rm $APTCACHER_DIR/pid-3
fi

report_info "Process finished"

exit 0
