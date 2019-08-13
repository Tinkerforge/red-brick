RED Brick Image Preparation
---------------------------

- Flash RED Brick image onto microSD card
- Disable all services to make the RED Brick boot to a virtual terminal
- Configure Ethernet Extension (tf0) with DHCP
- Upload tester.sh and tester.py as a Shell program with "Continue After Error"

RED Brick Test Procedure
------------------------

- Insert prepared microSD card into RED Brick
- Connect Step-Down Power Supply to RED Brick
- Connect 8 Master Bricks to RED Brick
- Connect Ethernet and RS485 Extension to stack
- Connect Ethernet Extension to network
- Connect Adafruit 5" HDMI display to HDMI and USB of the RED Brick
- Power Step-Down Power Supply
- Check that all three LEDs work
- Connect mini-USB cable to RED Brick
- Wait for the tester.py program to show the test results on the HDMI display
- Test is successful if RED Brick shows up in Brick Viewer on PC and all test
  results are positive
- Disconnect mini-USB cable from RED Brick before disconnecting power from
  Step-Down Power Supply to avoid powering the whole stack from USB
