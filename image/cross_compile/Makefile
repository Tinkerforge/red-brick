CCPATH := ../tools/gcc-linaro-arm-linux-gnueabihf-4.8-2013.10_linux/bin/
CC := $(CCPATH)arm-linux-gnueabihf-gcc

FILES = hello.c
OUT := hello

default :
	$(CC) $(FILES) -o $(OUT)

clean :
	/bin/rm -f *.o $(OUT)
