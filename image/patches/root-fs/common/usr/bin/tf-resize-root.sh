#! /bin/sh

ROOT_UID="0"

# Check if running as root
if [ "$(id -u)" -ne "$ROOT_UID" ]
then
    echo -e "\nError: You must be root to execute the script\n"
    exit 1
fi

echo -e "\nInfo: Resizing root partition...\n"

/sbin/resize2fs -p /dev/mmcblk0p1

echo -e "\nInfo: Process finished\n"

exit 0
