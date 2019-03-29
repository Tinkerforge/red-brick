#include <stdio.h>
#include <unistd.h>

#include "ip_connection.h"
#include "bricklet_industrial_dual_relay.h"

#define HOST "localhost"
#define PORT 4223
#define UID "xyz" // Change to your UID

int main() {
	// Create IP connection
	IPConnection ipcon;
	ipcon_create(&ipcon);

	// Create device object
	IndustrialDualRelay dr;
	industrial_dual_relay_create(&dr, UID, &ipcon); 

	// Connect to brickd
	if(ipcon_connect(&ipcon, HOST, PORT) < 0) {
		fprintf(stderr, "Could not connect\n");
		exit(1);
	}
	// Don't use device before ipcon is connected

	// Turn both relays off and on
	industrial_dual_relay_set_value(&dr, false, false);
	sleep(1);
	industrial_dual_relay_set_value(&dr, true, true);

	ipcon_destroy(&ipcon); // Calls ipcon_disconnect internally
}
