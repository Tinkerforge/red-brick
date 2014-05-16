#! /bin/bash -exu

. ./utilities.sh

ROOT_UID="0"

# Check if running as root
if [ "$(id -u)" -ne "$ROOT_UID" ]
then
    report_error "You must be root to execute the script"
    exit 1
fi

BASE_DIR=`pwd`
CONFIG_DIR="$BASE_DIR/config"

. $CONFIG_DIR/common.conf

mkdir -p $BUILD_DIR/apt-cacher
chown `logname`:`logname` $BUILD_DIR

mkdir -p $BUILD_DIR/apt-cacher/cache-0
apt-cacher -d -p $BUILD_DIR/apt-cacher/pid-0 cache_dir=$BUILD_DIR/apt-cacher/cache-0 log_dir=$BUILD_DIR/apt-cacher/log-0 daemon_port=3150 allowed_hosts=*

mkdir -p $BUILD_DIR/apt-cacher/cache-1
apt-cacher -d -p $BUILD_DIR/apt-cacher/pid-1 cache_dir=$BUILD_DIR/apt-cacher/cache-1 log_dir=$BUILD_DIR/apt-cacher/log-1 daemon_port=3151 allowed_hosts=*

mkdir -p $BUILD_DIR/apt-cacher/cache-2
apt-cacher -d -p $BUILD_DIR/apt-cacher/pid-2 cache_dir=$BUILD_DIR/apt-cacher/cache-2 log_dir=$BUILD_DIR/apt-cacher/log-2 daemon_port=3152 allowed_hosts=*

mkdir -p $BUILD_DIR/apt-cacher/cache-3
apt-cacher -d -p $BUILD_DIR/apt-cacher/pid-3 cache_dir=$BUILD_DIR/apt-cacher/cache-3 log_dir=$BUILD_DIR/apt-cacher/log-3 daemon_port=3153 allowed_hosts=*
