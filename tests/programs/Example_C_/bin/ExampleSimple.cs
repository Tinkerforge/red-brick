using Tinkerforge;

class Example
{
	private static string HOST = "localhost";
	private static int PORT = 4223;
	private static string UID = "xyz"; // Change to your UID

	static void Main() 
	{
		IPConnection ipcon = new IPConnection(); // Create IP connection
		BrickletDualRelay dr = new BrickletDualRelay(UID, ipcon); // Create device object

		ipcon.Connect(HOST, PORT); // Connect to brickd
		// Don't use device before ipcon is connected

		// Turn relays alternating on/off for 10 times with 1 second delay
		for(int i = 0; i < 10; i++)
		{
			System.Threading.Thread.Sleep(1000);
			if(i % 2 == 0) 
			{
				dr.SetState(true, false);
			} 
			else
			{
				dr.SetState(false, true);
			}
		}

		ipcon.Disconnect();
	}
}
