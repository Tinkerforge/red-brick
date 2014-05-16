#! /bin/bash -exu

. ./utilities.sh

BASE_DIR=`pwd`
CONFIG_DIR="$BASE_DIR/config"

. $CONFIG_DIR/common.conf

mkdir -p $BUILD_DIR/apt-cacher/cache-0
apt-cacher -d -c $CONFIG_DIR/apt-cacher.conf -p $BUILD_DIR/apt-cacher/pid-0 cache_dir=$BUILD_DIR/apt-cacher/cache-0 log_dir=$BUILD_DIR/apt-cacher/log-0 daemon_port=3150

mkdir -p $BUILD_DIR/apt-cacher/cache-1
apt-cacher -d -c $CONFIG_DIR/apt-cacher.conf -p $BUILD_DIR/apt-cacher/pid-1 cache_dir=$BUILD_DIR/apt-cacher/cache-1 log_dir=$BUILD_DIR/apt-cacher/log-1 daemon_port=3151

mkdir -p $BUILD_DIR/apt-cacher/cache-2
apt-cacher -d -c $CONFIG_DIR/apt-cacher.conf -p $BUILD_DIR/apt-cacher/pid-2 cache_dir=$BUILD_DIR/apt-cacher/cache-2 log_dir=$BUILD_DIR/apt-cacher/log-2 daemon_port=3152

mkdir -p $BUILD_DIR/apt-cacher/cache-3
apt-cacher -d -c $CONFIG_DIR/apt-cacher.conf -p $BUILD_DIR/apt-cacher/pid-3 cache_dir=$BUILD_DIR/apt-cacher/cache-3 log_dir=$BUILD_DIR/apt-cacher/log-3 daemon_port=3153

report_info "Process finished"

exit 0
