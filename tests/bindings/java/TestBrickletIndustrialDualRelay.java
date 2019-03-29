import com.tinkerforge.BrickletIndustrialDualRelay;
import com.tinkerforge.IPConnection;

public class TestBrickletIndustrialDualRelay {
	private static final String HOST = "localhost";
	private static final int PORT = 4223;
	private static final String UID = "xyz"; // Change to your UID

	// Note: To make the example code cleaner we do not handle exceptions. Exceptions you
	//       might normally want to catch are described in the documentation
	public static void main(String args[]) throws Exception {
		IPConnection ipcon = new IPConnection(); // Create IP connection
		BrickletIndustrialDualRelay dr = new BrickletIndustrialDualRelay(UID, ipcon); // Create device object

		ipcon.connect(HOST, PORT); // Connect to brickd
		// Don't use device before ipcon is connected

		// Turn both relays off and on
		dr.setValue(false, false);
		Thread.sleep(1000);
		dr.setValue(true, true);

		ipcon.disconnect();
	}
}
