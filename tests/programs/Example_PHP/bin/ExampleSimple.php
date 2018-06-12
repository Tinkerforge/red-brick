<?php

require_once('Tinkerforge/IPConnection.php');
require_once('Tinkerforge/BrickletDualRelay.php');

use Tinkerforge\IPConnection;
use Tinkerforge\BrickletDualRelay;

const HOST = 'localhost';
const PORT = 4223;
const UID = 'xyz'; // Change to your UID

$ipcon = new IPConnection(); // Create IP connection
$dr = new BrickletDualRelay(UID, $ipcon); // Create device object

$ipcon->connect(HOST, PORT); // Connect to brickd
// Don't use device before ipcon is connected

// Turn relays alternating on/off for 10 times with 1 second delay
for($i = 0; $i < 10; $i++) {
    sleep(1);

    if ($i % 2 == 1) {
        $dr->setState(TRUE, FALSE);
    } else {
        $dr->setState(FALSE, TRUE);
    }
}

$ipcon->disconnect();

?>
