#!/usr/bin/env python
# -*- coding: utf-8 -*-

HOST = 'localhost'
PORT = 4223
UID = 'XXYYZZ' # Change XXYYZZ to the UID of your RED Brick
LOCAL_PATH = 'foobar.txt' # Change to your local path
REMOTE_PATH = '/home/tf/foobar.txt' # Change to your remote path

import sys
from tinkerforge.ip_connection import IPConnection
from tinkerforge.brick_red import BrickRED

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

def write_file(red, local_path, remote_path):
    # Open local file for reading
    local_file = open(local_path, 'rb')

    # Create session
    session_id = check_error(*red.create_session(60))

    # Create remote non-executable file for writing as user/group tf
    remote_path_id = allocate_string(red, remote_path, session_id)
    remote_file_id = check_error(*red.open_file(remote_path_id,
                                                BrickRED.FILE_FLAG_WRITE_ONLY |
                                                BrickRED.FILE_FLAG_CREATE |
                                                BrickRED.FILE_FLAG_TRUNCATE |
                                                BrickRED.FILE_FLAG_NON_BLOCKING,
                                                0o644, 1000, 1000, session_id))

    check_error(red.release_object(remote_path_id, session_id))

    # Read local file and write to remote file
    transferred = 0

    while True:
        data = list(local_file.read(61))

        if sys.version_info[0] < 3:
            data = map(ord, data)

        if len(data) == 0:
            break

        length_to_write = len(data)
        data += [0] * (61 - length_to_write)
        length_written = check_error(*red.write_file(remote_file_id, data, length_to_write))

        if length_written != length_to_write:
            print('Short write')
            exit(1)

        check_error(red.keep_session_alive(session_id, 30))

        transferred += length_written

    # Close remote file
    check_error(red.release_object(remote_file_id, session_id))

    # Close local file
    local_file.close()

    # Expire session
    check_error(red.expire_session(session_id))

    print('{0} bytes transferred'.format(transferred))

if __name__ == '__main__':
    ipcon = IPConnection() # Create IP connection
    red = BrickRED(UID, ipcon) # Create device object

    ipcon.connect(HOST, PORT) # Connect to brickd
    # Don't use device before ipcon is connected

    write_file(red, LOCAL_PATH, REMOTE_PATH)

    input("Press key to exit\n") # Use raw_input() in Python 2
    ipcon.disconnect()
