#!/bin/bash -exu

# RED Brick Image Builder
# Copyright (C) 2019 Ishraq Ibne Ashraf <ishraq@tinkerforge.com>
#
# build.sh: Build RED Brick image
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

# Functions.
prepare-host() {
    ./${FUNCNAME[0]}.sh
}

update-source() {
    ./${FUNCNAME[0]}.sh
}

compile-source() {
    ./${FUNCNAME[0]}.sh $IMAGE_CONFIG
}

make-root-fs() {
    echo "tf" | sudo -S ./${FUNCNAME[0]}.sh $IMAGE_CONFIG
}

make-image() {
    echo "tf" | sudo -S ./${FUNCNAME[0]}.sh $IMAGE_CONFIG
}

start-apt-cacher() {
    ./${FUNCNAME[0]}.sh
}

stop-apt-cacher() {
    ./${FUNCNAME[0]}.sh
}

# Check args.
if [ "$#" -ne 1 ];
then
  echo "Usage: $0 <IMAGE-CONFIG>"

  exit 1
fi

IMAGE_CONFIG=$1

# Executing in container.
if grep docker /proc/1/cgroup -qa;
then
    prepare-host && \
    update-source && \
    compile-source && \
    start-apt-cacher && \
    make-root-fs && \
    stop-apt-cacher && \
    make-image

    exit 0
fi

# Executing in host.

#if [ "$?" -eq 0 ];
if [ $(which docker) ]
then
    # Build in container.
    echo "[$0]: Building in Docker"
    docker pull tinkerforge/build_environment_red_brick && \
    docker run --privileged -u tf -w /home/tf/red-brick-image -v $(pwd):/home/tf/red-brick-image -it tinkerforge/build_environment_red_brick ./build.sh $IMAGE_CONFIG

    exit 0
fi

# Build in host.
echo "[$0]: Building in host"
prepare-host && \
update-source && \
compile-source && \
start-apt-cacher && \
make-root-fs && \
stop-apt-cacher && \
make-image
