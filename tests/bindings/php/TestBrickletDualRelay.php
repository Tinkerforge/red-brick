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

// Turn both relays off and on
$dr->setState(FALSE, FALSE);
sleep(1);
$dr->setState(TRUE, TRUE);

$ipcon->disconnect();

?>
