#!/usr/bin/env python2
# -*- coding: utf-8 -*-

import sys
import time
import humod
import signal
from humod.at_commands import Command
from tinkerforge.ip_connection import IPConnection
from tinkerforge.bricklet_gps import GPS

HOST = "localhost"
PORT = 4223
UID = "XYZ" # Change to the UID of your humidity bricklet
PIN_SIM = '1234' # Change to your SIM card's PIN
CMD_SMS_LOC = 'tf:loc' # Command to send via SMS to get location

class ModemManager():
	MODEM = None
	CMD_CPIN = None
	CMD_CPOS = None
	CMD_CSCS = None
	CMD_STR_CPIN = '+CPIN' # PIN management
	CMD_STR_COPS = '+COPS' # Operator management
	CMD_STR_CSCS = '+CSCS' # Character set management
	ERR_MSG_INIT_MODEM = 'ERROR: Failed to initialze modem'
	ERR_MSG_PUK = 'ERROR: SIM requires PUK code'
	ERR_MSG_PIN_EMPTY = 'ERROR: SIM requires PIN but no PIN provided'
	ERR_MSG_PIN_QUERY = 'ERROR: SIM query for PIN failed'
	ERR_MSG_PIN_APPLY = 'ERROR: Failed to apply PIN'
	ERR_MSG_PIN_WRONG = 'ERROR: Wrong PIN supplied'
	ERR_MSG_PIN_UNDEFINED = 'ERROR: Undefined PIN status'
	ERR_MSG_CMD_CPOS_FAILED = 'ERROR: Setting auto search mode failed'
	ERR_MSG_SET_TEXTMODE_FAILED = 'ERROR: Setting text mode failed'
	ERR_MSG_SET_CHARACTER_SET_FAILED = 'ERROR: Failed to setup character set of the modem'
	ERR_MSG_NEW_SMS_CB_FAILED = 'ERROR: Failed register callback for new SMS'

	def __init__(self, tty_device_file, pin):
		try:
			self.MODEM = humod.Modem(tty_device_file, tty_device_file)
			signal.signal(signal.SIGALRM, self._handler_timeout_signal)
			signal.alarm(10)
			self.MODEM.show_model()
			signal.alarm(0)
		except:
			self.handle_error(self.ERR_MSG_INIT_MODEM)

		try:
			self.CMD_CPIN = Command(self.MODEM, self.CMD_STR_CPIN)
			pin_status = self.CMD_CPIN.get()[0]
		except:
			self.handle_error(self.ERR_MSG_PIN_QUERY)

		if 'IM PUK' in pin_status:
			self.handle_error(self.ERR_MSG_PUK)

		if 'IM PIN' in pin_status:
			if pin == '':
				self.handle_error(self.ERR_MSG_PIN_EMPTY)

			try:
				self.CMD_CPIN.set(pin)
			except:
				self.handle_error(self.ERR_MSG_PIN_APPLY)

			try:
				pin_status = self.CMD_CPIN.get()[0]
			except:
				self.handle_error(self.ERR_MSG_PIN_QUERY)

			if 'EADY' not in pin_status:
				self.handle_error(self.ERR_MSG_PIN_WRONG)
				return

		if 'EADY' not in pin_status:
			self.handle_error(self.ERR_MSG_PIN_UNDEFINED)

		try:
			self.CMD_CPOS = Command(self.MODEM, self.CMD_STR_COPS)
			self.CMD_CPOS.set(0)
		except:
			self.handle_error(self.ERR_MSG_CMD_CPOS_FAILED)

		time.sleep(10)

		try:
			self.CMD_CSCS = Command(self.MODEM, self.CMD_STR_CSCS)
			self.CMD_CSCS.set('"GSM"')
		except:
			self.handle_error(self.ERR_MSG_SET_CHARACTER_SET_FAILED)

		try:
			self.MODEM.enable_textmode(True)
		except:
			self.handle_error(self.ERR_MSG_SET_TEXTMODE_FAILED)

	def _handler_timeout_signal(self, signal_number, frame):
		raise Exception

	def handle_error(self, message):
		print message
		exit(1)

	def send_sms(self, number, message):
		try:
			self.CMD_CSCS.set('"GSM"')
			self.MODEM.sms_send(number, message)
		except:
			print 'ERROR: Failed to send SMS'

	def register_new_sms_callback(self, callback):
		try:
			self.MODEM.enable_nmi(True)
			self.MODEM.prober.start([(humod.actions.PATTERN['new sms'], callback)])
		except:
			self.handle_error(self.ERR_MSG_NEW_SMS_CB_FAILED)

	def stop_prober(self):
		self.MODEM.prober.stop()

if __name__ == '__main__':
	if len(sys.argv) != 2:
		print 'ERROR: Too many or too few arguments'
		exit(1)

	def cb_new_sms(modem, message):
		# Get current coordinates
		try:
			coords = gps.get_coordinates()
			la = 'Latitude: ' + str(coords.latitude/1000000.0) + ' ' + coords.ns
			lo = 'Longitude: ' + str(coords.longitude/1000000.0) + ' ' + coords.ew
			msg_body_send = la + '\n' + lo
		except:
			print 'ERROR: Failed to get GPS coordinates'
			return

		try:
			msg_index = int(message[12:].strip())
			msg_body_received = modem.sms_read(msg_index)

			if msg_body_received != CMD_SMS_LOC:
				return

			for msg_header in modem.sms_list():
				if msg_header[0] == msg_index - 1:
					sms_reply_to = msg_header[2]
					break
		except:
			print 'ERROR: Failed to process received SMS'
			return

		try:
			modem.sms_send(sms_reply_to, msg_body_send)
		except:
			# Ignore exceptions
			pass

		time.sleep(2)

	mm = ModemManager(sys.argv[1], PIN_SIM) # You can keep the PIN as empty string if PIN is disabled
	mm.register_new_sms_callback(cb_new_sms) # Register a callback for new SMS arrival event

	ipcon = IPConnection() # Create IP connection
	gps = GPS(UID, ipcon) # Create device object

	ipcon.connect(HOST, PORT) # Connect to brickd
	# Don't use device before ipcon is connected

	raw_input('Press any key to exit...\n') # Use input() in Python 3
	mm.stop_prober()
	ipcon.disconnect()
