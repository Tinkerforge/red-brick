#!/usr/bin/perl  

use Tinkerforge::IPConnection;
use Tinkerforge::BrickletIndustrialDualRelay;

use constant HOST => 'localhost';
use constant PORT => 4223;
use constant UID => 'xyz'; # Change to your UID

my $ipcon = Tinkerforge::IPConnection->new(); # Create IP connection
my $dr = Tinkerforge::BrickletIndustrialDualRelay->new(&UID, $ipcon); # Create device object

$ipcon->connect(&HOST, &PORT); # Connect to brickd
# Don't use device before ipcon is connected

# Turn both relays off and on
$dr->set_value(0, 0);
sleep(1);
$dr->set_value(1, 1);

$ipcon->disconnect();
