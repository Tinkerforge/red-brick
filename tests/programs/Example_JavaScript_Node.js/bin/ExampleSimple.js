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
        // Turn relays on/off
        dr.setState(true, false);
        setTimeout(
            function() {
                dr.setState(false, true);
                ipcon.disconnect();
                process.exit(0);
            },
            2000
        );
    }
);
