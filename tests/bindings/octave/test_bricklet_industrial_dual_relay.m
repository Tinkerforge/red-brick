function test_bricklet_industrial_dual_relay()
    more off;
    
    HOST = "localhost";
    PORT = 4223;
    UID = "xyz"; % Change to your UID

    ipcon = java_new("com.tinkerforge.IPConnection"); % Create IP connection
    dr = java_new("com.tinkerforge.BrickletIndustrialDualRelay", UID, ipcon); % Create device object

    ipcon.connect(HOST, PORT); % Connect to brickd
    % Don"t use device before ipcon is connected

    % Turn both relays off and on
    dr.setValue(false, false);
    pause(1);
    dr.setValue(true, true);

    ipcon.disconnect();
end

test_bricklet_industrial_dual_relay();
