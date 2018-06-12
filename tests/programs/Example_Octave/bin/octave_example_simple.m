function octave_example_simple()
    more off;
    
    HOST = "localhost";
    PORT = 4223;
    UID = "xyz"; % Change to your UID

    ipcon = java_new("com.tinkerforge.IPConnection"); % Create IP connection
    dr = java_new("com.tinkerforge.BrickletDualRelay", UID, ipcon); % Create device object

    ipcon.connect(HOST, PORT); % Connect to brickd
    % Don"t use device before ipcon is connected

    % Turn relays alternating on/off for 10 times with 1 second delay
    for i = 1:10
        pause(1);
        if mod(i, 2)
            dr.setState(true, false);
        else
            dr.setState(false, true);
        end
    end

    ipcon.disconnect();
end

octave_example_simple();
