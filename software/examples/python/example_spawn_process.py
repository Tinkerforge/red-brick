#!/usr/bin/env python
# -*- coding: utf-8 -*-

HOST = 'localhost'
PORT = 4223
UID = 'XXYYZZ' # Change XXYYZZ to the UID of your RED Brick

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

def spawn_process(red, executable, arguments):
    # Create session
    session_id = check_error(*red.create_session(60))

    # Prepare spawn-process call
    executable_id = allocate_string(red, executable, session_id)
    arguments_id = check_error(*red.allocate_list(1, session_id))

    for argument in arguments:
        argument_id = allocate_string(red, argument, session_id)
        check_error(red.append_to_list(arguments_id, argument_id))
        check_error(red.release_object(argument_id, session_id))

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
        check_error(red.keep_session_alive(session_id, 10))

    check_error(red.release_object(process_id, session_id))

    # Expire session
    check_error(red.expire_session(session_id))

    # Report result
    if state == BrickRED.PROCESS_STATE_ERROR:
        print('Executing {0} failed with an internal error'.format(executable))
    elif state == BrickRED.PROCESS_STATE_EXITED:
        if exit_code == 0:
            print('Executed {0}'.format(executable))
        else:
            # FIXME: Could report stdout/stderr from executable here
            print('Executing {0} failed with exit code {1}'.format(executable, exit_code))
    elif state == BrickRED.PROCESS_STATE_KILLED:
        print('Executing {0} was killed by signal {1}'.format(executable, exit_code))
    elif state == BrickRED.PROCESS_STATE_STOPPED:
        print('Executing {0} was stopped'.format(executable))
    else:
        print('Executing {0} failed with an unknown error'.format(executable))

if __name__ == '__main__':
    ipcon = IPConnection() # Create IP connection
    red = BrickRED(UID, ipcon) # Create device object

    ipcon.connect(HOST, PORT) # Connect to brickd
    # Don't use device before ipcon is connected

    spawn_process(red, 'touch', ['/tmp/foobar'])

    input("Press key to exit\n") # Use raw_input() in Python 2
    ipcon.disconnect()
