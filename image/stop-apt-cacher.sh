#! /bin/bash -exu

. ./utilities.sh
BASE_DIR=`pwd`
CONFIG_DIR="$BASE_DIR/config"

. $CONFIG_DIR/common.conf

if [ -f $APTCACHER_RUNNING_FILE ]
then
	report_info "Stopping apt-cacher daemons"

	if [ -f $APTCACHER_DIR/pid-0 ]
	then
		kill `cat $APTCACHER_DIR/pid-0`
		rm $APTCACHER_DIR/pid-0
	fi

	if [ -f $APTCACHER_DIR/pid-1 ]
	then
		kill `cat $APTCACHER_DIR/pid-1`
		rm $APTCACHER_DIR/pid-1
	fi

	if [ -f $APTCACHER_DIR/pid-2 ]
	then
		kill `cat $APTCACHER_DIR/pid-2`
		rm $APTCACHER_DIR/pid-2
	fi

	if [ -f $APTCACHER_DIR/pid-3 ]
	then
		kill `cat $APTCACHER_DIR/pid-3`
		rm $APTCACHER_DIR/pid-3
	fi

	rm $APTCACHER_RUNNING_FILE
else
	report_error "apt-cacher daemons not running"
	exit 1
fi

report_info "Process finished"

exit 0
