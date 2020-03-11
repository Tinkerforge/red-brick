#!/usr/bin/env python
# -*- coding: utf-8 -*-

HOST = 'localhost'
PORT = 4223
UID = 'XXYYZZ' # Change XXYYZZ to the UID of your RED Brick
REMOTE_PATH = '/home/tf/foobar.txt' # Change to your remote path

import sys
import time
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

def remove_file(red, remote_path):
    # Create session
    session_id = check_error(*red.create_session(60))

    # Prepare spawn-process call
    executable_id = allocate_string(red, '/bin/rm', session_id)

    remote_path_id = allocate_string(red, remote_path, session_id)
    arguments_id = check_error(*red.allocate_list(1, session_id))
    check_error(red.append_to_list(arguments_id, remote_path_id))
    check_error(red.release_object(remote_path_id, session_id))

    environment_id = check_error(*red.allocate_list(0, session_id))

    working_directory_id = allocate_string(red, '/', session_id)

    dev_zero_id = allocate_string(red, '/dev/zero', session_id)
    stdin_id = check_error(*red.open_file(dev_zero_id,
                                          BrickRED.FILE_FLAG_READ_ONLY |
                                          BrickRED.FILE_FLAG_NON_BLOCKING,
                                          0, 1000, 1000, session_id))
    check_error(red.release_object(dev_zero_id, session_id))

    dev_null_id = allocate_string(red, '/dev/null', session_id)
    stdout_id = check_error(*red.open_file(dev_null_id,
                                           BrickRED.FILE_FLAG_WRITE_ONLY |
                                           BrickRED.FILE_FLAG_NON_BLOCKING,
                                           0, 1000, 1000, session_id))
    check_error(red.release_object(dev_null_id, session_id))

    # Spawn rm process to remove remote file
    process_id = check_error(*red.spawn_process(executable_id,
                                                arguments_id,
                                                environment_id,
                                                working_directory_id,
                                                1000, 1000,
                                                stdin_id,
                                                stdout_id,
                                                stdout_id,
                                                session_id))
    check_error(red.release_object(executable_id, session_id))
    check_error(red.release_object(arguments_id, session_id))
    check_error(red.release_object(environment_id, session_id))
    check_error(red.release_object(working_directory_id, session_id))
    check_error(red.release_object(stdin_id, session_id))
    check_error(red.release_object(stdout_id, session_id))

    # Busy wait for rm process to finish
    # FIXME: Could use CALLBACK_PROCESS_STATE_CHANGED instead
    state, timestamp, exit_code = check_error(*red.get_process_state(process_id))

    while state in [BrickRED.PROCESS_STATE_UNKNOWN, BrickRED.PROCESS_STATE_RUNNING]:
        time.sleep(0.1)

        state, timestamp, exit_code = check_error(*red.get_process_state(process_id))

    check_error(red.release_object(process_id, session_id))

    # Expire session
    check_error(red.expire_session(session_id))

    # Report result
    if state == BrickRED.PROCESS_STATE_ERROR:
        print('Removing {0} failed with an internal error'.format(remote_path))
    elif state == BrickRED.PROCESS_STATE_EXITED:
        if exit_code == 0:
            print('Removed {0}'.format(remote_path))
        else:
            # FIXME: Could report stdout/stderr from /bin/rm here
            print('Removing {0} failed with /bin/rm exit code {1}'.format(remote_path, exit_code))
    elif state == BrickRED.PROCESS_STATE_KILLED:
        print('Removing {0} failed with /bin/rm being killed by signal {1}'.format(remote_path, exit_code))
    elif state == BrickRED.PROCESS_STATE_STOPPED:
        print('Removing {0} failed with /bin/rm being stopped')
    else:
        print('Removing {0} failed with an unknown error'.format(remote_path))

if __name__ == '__main__':
    ipcon = IPConnection() # Create IP connection
    red = BrickRED(UID, ipcon) # Create device object

    ipcon.connect(HOST, PORT) # Connect to brickd
    # Don't use device before ipcon is connected

    remove_file(red, REMOTE_PATH)

    input("Press key to exit\n") # Use raw_input() in Python 2
    ipcon.disconnect()
