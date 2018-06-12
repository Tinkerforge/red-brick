#!/usr/bin/perl  

use Tinkerforge::IPConnection;
use Tinkerforge::BrickletDualRelay;

use constant HOST => 'localhost';
use constant PORT => 4223;
use constant UID => 'xyz'; # Change to your UID

my $ipcon = Tinkerforge::IPConnection->new(); # Create IP connection
my $dr = Tinkerforge::BrickletDualRelay->new(&UID, $ipcon); # Create device object

$ipcon->connect(&HOST, &PORT); # Connect to brickd
# Don't use device before ipcon is connected

# Turn both relays off and on
$dr->set_state(0, 0);
sleep(1);
$dr->set_state(1, 1);

$ipcon->disconnect();
