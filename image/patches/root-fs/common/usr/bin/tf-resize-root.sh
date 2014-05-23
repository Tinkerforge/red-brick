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

# Generate and setup ´tmp-tf-resize-root´ script
/bin/echo -e "#! /bin/sh
### BEGIN INIT INFO
# Provides:          tmp-tf-resize-rootfs
# Required-Start:
# Required-Stop:
# Default-Start:     2
# Default-Stop:
# Short-Description: Resizes the root file system
# Description:       Resizes the root file system
### END INIT INFO

case \"\$1\" in 
    start)
	echo \"
Info: Expanding the root filesystem (this might take sometime)...
\"
        /sbin/resize2fs -p /dev/mmcblk0p1
        /sbin/insserv -r /etc/init.d/tmp-tf-resize-root
        rm \$0
        ;;
esac

exit 0" > /etc/init.d/tmp-tf-resize-root
/bin/chmod a+x /etc/init.d/tmp-tf-resize-root
/sbin/insserv /etc/init.d/tmp-tf-resize-root

read -p "
Prompt: You need to reboot the system to complete the resize.
Reboot now? (Type 'y' to reboot instantly) >> " PROMPT_RESP

if [ "$PROMPT_RESP" = "y" ];
then
/bin/echo -e "\nInfo: Rebooting the system...\n"
/sbin/reboot
fi

echo -e "\nInfo: Process finished\n"

exit 0
