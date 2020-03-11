#!/usr/bin/env python
# -*- coding: utf-8 -*-

HOST = 'localhost'
PORT = 4223
UID = 'XXYYZZ' # Change XXYYZZ to the UID of your RED Brick
REMOTE_PATH = '/home/tf/foobar.txt' # Change to your remote path
LOCAL_PATH = 'foobar.txt' # Change to your local path

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

def read_file(red, remote_path, local_path):
    # Create session
    session_id = check_error(*red.create_session(60))

    # Create remote non-executable file for writing as user/group tf
    remote_path_id = allocate_string(red, remote_path, session_id)
    remote_file_id = check_error(*red.open_file(remote_path_id,
                                                BrickRED.FILE_FLAG_READ_ONLY |
                                                BrickRED.FILE_FLAG_NON_BLOCKING,
                                                0, 0, 0, session_id))

    check_error(red.release_object(remote_path_id, session_id))

    # Open local file for writing
    local_file = open(local_path, 'wb')

    # Read remote file and write to local file
    transferred = 0

    while True:
        data, length_read = check_error(*red.read_file(remote_file_id, 61))
        data = data[:length_read]

        if len(data) == 0:
            break

        if sys.version_info[0] > 2:
            local_file.write(bytes(data))
        else:
            local_file.write(''.join(map(chr, data)))

        check_error(red.keep_session_alive(session_id, 30))

        transferred += length_read

    # Close local file
    local_file.close()

    # Close remote file
    check_error(red.release_object(remote_file_id, session_id))

    # Expire session
    check_error(red.expire_session(session_id))

    print('{0} bytes transferred'.format(transferred))

if __name__ == '__main__':
    ipcon = IPConnection() # Create IP connection
    red = BrickRED(UID, ipcon) # Create device object

    ipcon.connect(HOST, PORT) # Connect to brickd
    # Don't use device before ipcon is connected

    read_file(red, REMOTE_PATH, LOCAL_PATH)

    input("Press key to exit\n") # Use raw_input() in Python 2
    ipcon.disconnect()
