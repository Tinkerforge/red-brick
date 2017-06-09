load mmc 0:1 0x46000000 boot/vmlinuz
load mmc 0:1 0x49000000 boot/dt/red-brick.dtb

setenv bootargs_main console=tty1 earlyprintk=serial,ttyS3,115200n8 root=/dev/mmcblk0p1 rw init=/sbin/init quiet splash loglevel=7 panic=5 consoleblank=0
setenv bootargs_extra hdmi.audio=EDID:0 disp.screen0_output_mode=EDID:800x480p60
setenv bootargs "${bootargs_main} ${bootargs_extra}"

bootz 0x46000000 - 0x49000000
