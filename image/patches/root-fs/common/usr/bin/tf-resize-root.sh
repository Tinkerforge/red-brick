#! /bin/sh

ROOT_UID="0"

# Check if running as root
if [ "$(id -u)" -ne "$ROOT_UID" ]
then
    /bin/echo -e "\nError: You must be root to execute the script\n"
    exit 1
fi

PART_START=20480

# Do the partition structure modification
/bin/echo -e "\nInfo: Modifying the partition structure...\n"
/sbin/fdisk /dev/mmcblk0<<EOF
d
n
p
1
$PART_START

w
EOF

# Generate and setup ´S00resize_partition´ script
/bin/echo -e "#! /bin/sh

/bin/echo \"
Info: Resizing root partition...
\"
/sbin/resize2fs -p /dev/mmcblk0p1
rm \$0
" > /etc/rc2.d/S00resize_partition
chmod a+x /etc/rc2.d/S00resize_partition

read -p "Prompt: You need to reboot the system to complete the resize.
Reboot now? (Type 'y' to reboot instantly) >> " PROMPT_RESP

if [ "$PROMPT_RESP" = "y" ];
then
/bin/echo -e "\nInfo: Rebooting the system...\n"
/sbin/reboot
fi

echo -e "\nInfo: Process finished\n"

exit 0
