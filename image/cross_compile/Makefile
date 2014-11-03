# Defines
CCPATH := ../tools/gcc-linaro-arm-linux-gnueabihf-4.8-2013.10_linux/bin/
CC := $(CCPATH)arm-linux-gnueabihf-gcc
CFLAGS=-c -Wall
EXE=hello
SOURCES=hello.c
OBJECTS=$(SOURCES:.cpp=.o)

# Build Rules
all: $(SOURCES) $(EXE)

.cpp.o:
	$(CC) $(CFLAGS) $< -o $@

$(EXE): $(OBJECTS)
	$(CC) $(OBJECTS) -o $(EXE)

clean: 
	rm -f *.o $(EXE)
