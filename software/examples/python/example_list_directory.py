#!/usr/bin/env python
# -*- coding: utf-8 -*-

HOST = 'localhost'
PORT = 4223
UID = 'XXYYZZ' # Change XXYYZZ to the UID of your RED Brick
DIRECTORY_PATH = '/home/tf' # Change to your directory path

import sys
from tinkerforge.ip_connection import IPConnection
from tinkerforge.brick_red import BrickRED

DIRECTORY_ENTRY_TYPE = {
    BrickRED.DIRECTORY_ENTRY_TYPE_UNKNOWN: 'unknown',
    BrickRED.DIRECTORY_ENTRY_TYPE_REGULAR: 'regular',
    BrickRED.DIRECTORY_ENTRY_TYPE_DIRECTORY: 'directory',
    BrickRED.DIRECTORY_ENTRY_TYPE_CHARACTER: 'character',
    BrickRED.DIRECTORY_ENTRY_TYPE_BLOCK: 'block',
    BrickRED.DIRECTORY_ENTRY_TYPE_FIFO: 'fifo',
    BrickRED.DIRECTORY_ENTRY_TYPE_SYMLINK: 'symlink',
    BrickRED.DIRECTORY_ENTRY_TYPE_SOCKET: 'socket'
}

def check_error(error_code, *args):
    if error_code != 0:
        raise Exception('RED Brick error occurred: {0}'.format(error_code))

    if len(args) == 1:
        return args[0]

    return args

def allocate_string(red, string, session_id):
    string_id = check_error(*red.allocate_string(len(string), string[:58], session_id))

    for offset in range(58, len(string), 58):
        check_error(red.set_string_chunk(string_id, offset, string[offset:offset + 58]))

    return string_id

def get_string(red, string_id):
    length = check_error(*red.get_string_length(string_id))
    string = []

    while len(string) < length:
        chunk = check_error(*red.get_string_chunk(string_id, len(string)))
        string += map(ord, chunk)

    if sys.version_info[0] > 2:
        string = bytes(string)
    else:
        string = ''.join(map(chr, string))

    return string.decode('utf-8')

def list_directory(red, directory_path):
    # Create session
    session_id = check_error(*red.create_session(60))

    # Open directory
    directory_path_id = allocate_string(red, directory_path, session_id)
    directory_id = check_error(*red.open_directory(directory_path_id, session_id))

    check_error(red.release_object(directory_path_id, session_id))

    # Get directory entries
    while True:
        result = red.get_next_directory_entry(directory_id, session_id)

        if result.error_code == BrickRED.ERROR_CODE_NO_MORE_DATA:
            break

        entry_name_id, entry_type = check_error(*result)
        entry_name = get_string(red, entry_name_id)

        check_error(red.release_object(entry_name_id, session_id))

        print('name: {0}, type: {1}'.format(entry_name, DIRECTORY_ENTRY_TYPE[entry_type]))

    # Close directory
    check_error(red.release_object(directory_id, session_id))

    # Expire session
    check_error(red.expire_session(session_id))

if __name__ == '__main__':
    ipcon = IPConnection() # Create IP connection
    red = BrickRED(UID, ipcon) # Create device object

    ipcon.connect(HOST, PORT) # Connect to brickd
    # Don't use device before ipcon is connected

    list_directory(red, DIRECTORY_PATH)

    input("Press key to exit\n") # Use raw_input() in Python 2
    ipcon.disconnect()
