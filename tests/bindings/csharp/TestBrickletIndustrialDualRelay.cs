using Tinkerforge;

class TestBrickletIndustrialDualRelay
{
    private static string HOST = "localhost";
    private static int PORT = 4223;
    private static string UID = "xyz"; // Change XYZ to the UID of your Industrial Dual Relay Bricklet

    static void Main()
    {
        IPConnection ipcon = new IPConnection(); // Create IP connection
        BrickletIndustrialDualRelay idr =
          new BrickletIndustrialDualRelay(UID, ipcon); // Create device object

        ipcon.Connect(HOST, PORT); // Connect to brickd
        // Don't use device before ipcon is connected

        idr.SetValue(true, false);
        System.Threading.Thread.Sleep(1000);
        idr.SetValue(false, true);

        ipcon.Disconnect();
    }
}
