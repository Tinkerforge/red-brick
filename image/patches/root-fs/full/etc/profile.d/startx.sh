# if logging into tty2 (which will autologin), run startx
if [ -z "$DISPLAY" ] && [ $(tty) = /dev/tty2 ]; then
    exec startx
fi
