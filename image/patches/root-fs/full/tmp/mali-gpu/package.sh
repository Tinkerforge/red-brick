#!/bin/sh

sudo chown -R root:root libegl1-mesa_2-10.3.2-1_armhf
dpkg -b libegl1-mesa_2-10.3.2-1_armhf libegl1-mesa_2-10.3.2-1_armhf.deb
sudo chown -R 1000:1000 libegl1-mesa_2-10.3.2-1_armhf

sudo chown -R root:root libegl1-mesa-dev_2-10.3.2-1_armhf
dpkg -b libegl1-mesa-dev_2-10.3.2-1_armhf libegl1-mesa-dev_2-10.3.2-1_armhf.deb
sudo chown -R 1000:1000 libegl1-mesa-dev_2-10.3.2-1_armhf

sudo chown -R root:root libgles1-mesa_2-10.3.2-1_armhf
dpkg -b libgles1-mesa_2-10.3.2-1_armhf libgles1-mesa_2-10.3.2-1_armhf.deb
sudo chown -R 1000:1000 libgles1-mesa_2-10.3.2-1_armhf

sudo chown -R root:root libgles2-mesa_2-10.3.2-1_armhf
dpkg -b libgles2-mesa_2-10.3.2-1_armhf libgles2-mesa_2-10.3.2-1_armhf.deb
sudo chown -R 1000:1000 libgles2-mesa_2-10.3.2-1_armhf

sudo chown -R root:root libgles2-mesa-dev_2-10.3.2-1_armhf
dpkg -b libgles2-mesa-dev_2-10.3.2-1_armhf libgles2-mesa-dev_2-10.3.2-1_armhf.deb
sudo chown -R 1000:1000 libgles2-mesa-dev_2-10.3.2-1_armhf
