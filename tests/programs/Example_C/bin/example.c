
#include <stdio.h>

#include "ip_connection.h"
#include "bricklet_dual_relay.h"

#define HOST "localhost"
#define PORT 4223
#define UID "xyz" // Change to your UID

int main() {
	// Create IP connection
	IPConnection ipcon;
	ipcon_create(&ipcon);

	// Create device object
	DualRelay dr;
	dual_relay_create(&dr, UID, &ipcon); 

	// Connect to brickd
	if(ipcon_connect(&ipcon, HOST, PORT) < 0) {
		fprintf(stderr, "Could not connect\n");
		exit(1);
	}
	// Don't use device before ipcon is connected

	// Turn relay 1 on and relay 2 off.
	dual_relay_set_state(&dr, true, false);

	ipcon_destroy(&ipcon); // Calls ipcon_disconnect internally
}
