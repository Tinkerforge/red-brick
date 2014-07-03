#! /bin/bash

if [ "$1" = "wireless" ]
then
	/usr/bin/wicd-cli --wireless -n 0 -p automatic -s 1
fi
