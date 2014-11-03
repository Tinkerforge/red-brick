# Defines
CCPATH := ../tools/gcc-linaro-arm-linux-gnueabihf-4.8-2013.10_linux/bin/
CC := $(CCPATH)arm-linux-gnueabihf-gcc
CFLAGS=-c -Wall
EXE=hello
SOURCES=hello.c
OBJECTS=$(SOURCES:.c=.o)

# Build Rules
all: $(SOURCES) $(EXE)

.c.o:
	$(CC) $(CFLAGS) $< -o $@

$(EXE): $(OBJECTS)
	$(CC) $(OBJECTS) -o $(EXE)

clean:
	rm -f *.o $(EXE)
