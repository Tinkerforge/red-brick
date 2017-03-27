load mmc 0:1 0x46000000 boot/kernel/zImage
load mmc 0:1 0x49000000 boot/kernel/dtb/red-brick.dtb

setenv bootargs_linux console=ttyS2,115200n81 earlyprintk=serial,ttyS0,115200n81 root=/dev/mmcblk0p1 rw init=/sbin/init quiet splash loglevel=7 panic=5 consoleblank=0 
setenv bootargs_extra sunxi_ve_mem_reserve=0 sunxi_g2d_mem_reserve=0 sunxi_fb_mem_reserve=16 disp.screen0_output_mode=EDID:800x480p60 hdmi.audio=EDID:0
setenv bootargs "${bootargs_linux} ${bootargs_extra}"

bootz 0x46000000 - 0x49000000

