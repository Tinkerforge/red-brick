#! /bin/bash -exu

if [ "$#" -ne 2 ]; then
    echo "usage: dd-image.sh <image> <device>"
    exit 1
fi

pv -tpreb $1 | dd of=$2 bs=64M
