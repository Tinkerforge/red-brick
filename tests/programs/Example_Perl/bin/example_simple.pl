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

# Turn relays alternating on/off for 10 times with 1 second delay
for (my $i = 1; $i < 11; $i++)
{
    sleep(1);
    
    if ($i % 2)
    {
        $dr->set_state(1, 0);
    }    
    else
    {
        $dr->set_state(0, 1);
    }
}

$ipcon->disconnect();
