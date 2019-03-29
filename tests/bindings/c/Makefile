# Defines
CC=g++
CFLAGS=-c -Wall -I/usr/include/tinkerforge
LIBS=-ltinkerforge -lpthread
EXE=test_bricklet_industrial_dual_relay
SOURCES=test_bricklet_industrial_dual_relay.c
OBJECTS=$(SOURCES:.c=.o)

# Build Rules
all: $(SOURCES) $(EXE)

.c.o:
	$(CC) $(CFLAGS) $< -o $@

$(EXE): $(OBJECTS)
	$(CC) $(OBJECTS) -o $(EXE) $(LIBS)

clean:
	rm -f *.o $(EXE)
