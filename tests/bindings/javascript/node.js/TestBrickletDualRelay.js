var Tinkerforge = require('tinkerforge');

var HOST = 'localhost';
var PORT = 4223;
var UID = 'xyz'; // Change to your UID

var ipcon = new Tinkerforge.IPConnection(); // Create IP connection
var dr = new Tinkerforge.BrickletDualRelay(UID, ipcon); // Create device object

ipcon.connect(HOST, PORT,
    function(error) {
        console.log('Error: '+error);
    }
); // Connect to brickd
// Don't use device before ipcon is connected

ipcon.on(Tinkerforge.IPConnection.CALLBACK_CONNECTED,
    function(connectReason) {
        // Turn both relays off and on
        dr.setState(false, false);

        setTimeout(function() {
            dr.setState(true, true);
        }, 1000);
    }
);
