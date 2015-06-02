import com.tinkerforge.BrickRED;
import com.tinkerforge.IPConnection;
import com.tinkerforge.TinkerforgeException;

public class ExampleStartProgram {
	private static final String HOST = "localhost";
	private static final int PORT = 4223;
	private static final String UID = "3dfEZD"; // Change to your UID
	private static final String PROGRAM = "test"; // Change to your program identifier

	private static void checkError(short errorCode) {
		if (errorCode != 0) {
			throw new RuntimeException("RED Brick error occurred: " + errorCode);
		}
	}

	private static boolean startProgram(BrickRED red, String identifier)
	  throws TinkerforgeException {
		// Create session and get program list
		BrickRED.CreateSession session = red.createSession(10);
		checkError(session.errorCode);

		BrickRED.Programs programs = red.getPrograms(session.sessionId);
		checkError(programs.errorCode);

		BrickRED.ListLength programCount = red.getListLength(programs.programsListId);
		checkError(programCount.errorCode);

		// Iterate program list to find the one to start
		boolean started = false;

		for (int i = 0; i < programCount.length; i++) {
			BrickRED.ListItem program = red.getListItem(programs.programsListId, i,
			                                            session.sessionId);
			checkError(program.errorCode);

			// Get program identifer string
			BrickRED.ProgramIdentifier programIdentifier =
			  red.getProgramIdentifier(program.itemObjectId, session.sessionId);
			checkError(programIdentifier.errorCode);

			BrickRED.StringLength stringLength =
			  red.getStringLength(programIdentifier.identifierStringId);
			checkError(stringLength.errorCode);

			String stringData = "";

			while (stringData.length() < stringLength.length) {
				BrickRED.StringChunk chunk =
				  red.getStringChunk(programIdentifier.identifierStringId,
				                     stringData.length());
				checkError(chunk.errorCode);

				stringData += chunk.buffer;
			}

			checkError(red.releaseObject(programIdentifier.identifierStringId,
			                             session.sessionId));

			// Check if this is the program to be started
			if (stringData.equalsIgnoreCase(identifier)) {
				checkError(red.startProgram(program.itemObjectId));
				started = true;
			}

			checkError(red.releaseObject(program.itemObjectId, session.sessionId));

			if (started) {
				break;
			}
		}

		checkError(red.releaseObject(programs.programsListId, session.sessionId));
		checkError(red.expireSession(session.sessionId));

		return started;
	}

	// Note: To make the example code cleaner we do not handle exceptions. Exceptions you
	//       might normally want to catch are described in the documentation
	public static void main(String args[]) throws Exception {
		IPConnection ipcon = new IPConnection(); // Create IP connection
		BrickRED red = new BrickRED(UID, ipcon); // Create device object

		ipcon.connect(HOST, PORT); // Connect to brickd
		// Don't use device before ipcon is connected

		if (startProgram(red, PROGRAM)) {
			System.out.println("Started RED Brick program: " + PROGRAM);
		} else {
			System.out.println("RED Brick program not found: " + PROGRAM);
		}

		System.out.println("Press key to exit"); System.in.read();
		ipcon.disconnect();
	}
}
