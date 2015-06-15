#!/usr/bin/env python
# -*- coding: utf-8 -*-

HOST = 'localhost'
PORT = 4223
UID = '3dfEZD' # Change to your UID
PROGRAM = 'test' # Change to your program identifier

from tinkerforge.ip_connection import IPConnection
from tinkerforge.brick_red import RED

def check_error(error_code, *args):
    if error_code != 0:
        print('RED Brick error occurred: {0}'.format(error_code))
        exit(1)

    if len(args) == 1:
        return args[0]

    return args

def start_program(red, identifier):
    # Create session and get program list
    session_id = check_error(*red.create_session(10))
    program_list_id = check_error(*red.get_programs(session_id))

    # Iterate program list to find the one to start
    started = False

    for i in range(check_error(*red.get_list_length(program_list_id))):
        program_id, _ = check_error(*red.get_list_item(program_list_id, i, session_id))

        # Get program identifier string
        string_id = check_error(*red.get_program_identifier(program_id, session_id))
        string_length = check_error(*red.get_string_length(string_id))
        string_data = ''

        while len(string_data) < string_length:
            string_data += check_error(*red.get_string_chunk(string_id, len(string_data)))

        check_error(red.release_object(string_id, session_id))

        # Check if this is the program to be started
        if string_data.decode('utf-8') == identifier:
            check_error(red.start_program(program_id))
            started = True

        check_error(red.release_object(program_id, session_id))

        if started:
            break

    check_error(red.release_object(program_list_id, session_id))
    check_error(red.expire_session(session_id))

    return started

if __name__ == '__main__':
    ipcon = IPConnection() # Create IP connection
    red = RED(UID, ipcon) # Create device object

    ipcon.connect(HOST, PORT) # Connect to brickd
    # Don't use device before ipcon is connected

    if start_program(red, PROGRAM):
        print('Started RED Brick program: {0}'.format(PROGRAM))
    else:
        print('RED Brick program not found: {0}'.format(PROGRAM))

    raw_input('Press key to exit\n') # Use input() in Python 3
    ipcon.disconnect()
