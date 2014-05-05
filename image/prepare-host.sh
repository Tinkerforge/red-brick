#!/bin/bash

# run as root

set -e

echo -e "\nInfo: Installing tools\n"

apt-get install qemu-user-static multistrap git-core

exit 0
