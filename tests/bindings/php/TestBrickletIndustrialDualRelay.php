<?php

require_once('Tinkerforge/IPConnection.php');
require_once('Tinkerforge/BrickletIndustrialDualRelay.php');

use Tinkerforge\IPConnection;
use Tinkerforge\BrickletIndustrialDualRelay;

const HOST = 'localhost';
const PORT = 4223;
const UID = 'xyz'; // Change to your UID

$ipcon = new IPConnection(); // Create IP connection
$dr = new BrickletIndustrialDualRelay(UID, $ipcon); // Create device object

$ipcon->connect(HOST, PORT); // Connect to brickd
// Don't use device before ipcon is connected

// Turn both relays off and on
$dr->setValue(FALSE, FALSE);
sleep(1);
$dr->setValue(TRUE, TRUE);

$ipcon->disconnect();

?>
