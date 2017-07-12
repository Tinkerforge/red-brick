# if logging into tty2 (which will autologin), run startx
if [ -f /etc/tf_x11_enabled ] && [ -z "$DISPLAY" ] && [ $(tty) = /dev/tty2 ]; then
    chvt 2
    exec startx &> /dev/null
fi
