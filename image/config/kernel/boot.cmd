load mmc 0:1 0x46000000 boot/vmlinuz
load mmc 0:1 0x49000000 boot/dt/red-brick.dtb

setenv arg_console console=tty1
setenv arg_earlyprintk earlyprintk=serial,ttyS3,115200n8
setenv arg_rootfs root=/dev/mmcblk0p1 rw
setenv arg_init init=/sbin/init
setenv arg_other quiet splash loglevel=0 panic=5 consoleblank=0 drm_kms_helper.poll=0

setenv bootargs "${arg_console} ${arg_earlyprintk} ${arg_rootfs} ${arg_init} ${arg_other}"

saveenv

bootz 0x46000000 - 0x49000000
