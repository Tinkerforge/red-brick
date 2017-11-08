#!/usr/bin/env python
# -*- coding: UTF-8 -*-

import subprocess
from flask import Flask, request # Use Flask framework
from distutils.version import StrictVersion

application = Flask(__name__)    # Function "application" is used by Apache/WSGI
app = application                # Use shortcut for routing

import os
import cgi

IMAGE_VERSION = None

with open('/etc/tf_image_version', 'r') as f:
    IMAGE_VERSION = StrictVersion(f.read().split(' ')[0].strip())

PATH_PROGRAMS = os.path.join('/', 'home', 'tf', 'programs')

def get_program_ids():
    try:
        return os.listdir(PATH_PROGRAMS)
    except:
        return []

def get_program_name(config_path):
    with open(config_path, 'r') as f:
        for line in f:
            if line.startswith('custom.name ='):
                return line[len('custom.name ='):].strip().decode('string_escape')

    return '<unknown>'

@app.route('/')
def index():
    program_infos = {}
    for i in get_program_ids():
        program_infos[i] = {}
        program_infos[i]['name'] = get_program_name(os.path.join(PATH_PROGRAMS, i, 'program.conf'))
        program_infos[i]['url_config'] = os.path.join('/', 'programs', i, 'program.conf')
        program_infos[i]['url_log'] = os.path.join('/', 'programs', i, 'log')
        program_infos[i]['url_bin'] = os.path.join('/', 'programs', i, 'bin')

    box_num = ['A', 'B', 'C']
    program_boxes = ''
    for i, program_info in enumerate(sorted(program_infos.values())):
        program_boxes += PROGRAM_BOX.format(box_num[i % 3],
                                            cgi.escape(program_info['name']),
                                            program_info['url_log'],
                                            program_info['url_bin'],
                                            program_info['url_config'])

    if os.path.isfile('/etc/tf_server_monitoring_enabled'):
        nagios_status = 'enabled'
    else:
        nagios_status = 'disabled'

    openhab_status = 'in unknown state'
    openhab_button_state_class = 'smallbutton'

    ps = subprocess.Popen('/bin/systemctl is-enabled openhab2.service',
                          shell=True,
                          stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE)

    ps_stdout = ps.communicate()[0].strip()

    if ps_stdout and ps_stdout == 'disabled':
        openhab_status = 'disabled'
        openhab_button_state_class = 'smallbutton-disabled'
    elif ps_stdout and ps_stdout == 'enabled':
        openhab_status = 'enabled'

    return PAGE.format(len(program_infos),
                       program_boxes,
                       openhab_status,
                       request.host,
                       openhab_button_state_class,
                       nagios_status)

PAGE = """
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<title>RED Brick Web Interface</title>
<link href="red.css" rel="stylesheet" type="text/css" media="all" />
</head>
<body>
<div id="wrapper">
    <div id="banner">
        <div class="container">
            <div class="title">
                <h2>Welcome to the <strong>RED Brick</strong> web interface</h2>
            </div>
            <p>For information on how to use the RED Brick please visit the extensive online documentation.</p>
            <ul class="actions">
                <li><a href="http://www.tinkerforge.com/en/doc/Hardware/Bricks/RED_Brick.html" target="_blank" class="button">RED Brick Documentation</a></li>
            </ul>
        </div>
    </div>
    <div id="programs" class="container">
        <div class="title">
            <h2>Programs</h2>
            <span class="byline">Currently there are <strong>{0}</strong> programs available on the RED Brick</span>
        </div>
        <p>
            For each program you can view the config, the logs and the binaries. If you uploaded an
            <strong>index.py</strong>, <strong>index.php</strong> or <strong>index.html</strong>
            the respective file will be used as directory index for the binary folder.
        </p>
        <p>
            <strong>Example:</strong> If you want to write a PHP website that controls Bricks/Bricklets you can
            upload your program <strong>EXAMPLE</strong> with identifier <strong>EXAMPLE-ID</strong> that
            includes an index.php as starting point. If you now go to this website and click on
            the "Bin" button for the newly created program, you will get a link to
            <strong>/programs/EXAMPLE-ID/bin</strong>, which will directly execute the index.php
            if opened.
        </p>
        <div id="three-column">
{1}
        </div>
    </div>
    <div id="openhab" class="container">
        <div class="title">
            <h2>openHAB</h2>
            <span class="byline">Currently this service is <strong>{2}</strong> on the RED Brick</span>
        </div>
        <p>
            When this service is enabled openHAB web interface can be accessed
            by clicking the button below for configuring and using openHAB. This
            service can be enabled or disabled from the services tab and openHAB
            configuration files can be viewed and modified from openHAB settings
            tab of Brick Viewer.
        </p>
        <ul class="actions">
            <li><a href="http://{3}:8080/" target="_blank" class="{4}">openHAB Web Interface</a></li>
        </ul>
        <div id="three-column">
        </div>
    </div>
    <div id="servermonitoring" class="container">
        <div class="title">
            <h2>Server Monitoring</h2>
            <span class="byline">Currently this service is <strong>{5}</strong> on the RED Brick</span>
        </div>
        <p>
            Monitoring rules for different Bricklets can be configured using the server monitoring settings tab of Brick Viewer.
            For more advanced configurations you can directly access the Nagios configuration web interface using the link below.
            The default username is <strong>nagiosadmin</strong> and the default password is <strong>tf</strong>.
        </p>
        <ul class="actions">
            <li><a href="/nagios" target="_blank" class="smallbutton">Nagios Status and Configuration</a></li>
        </ul>
    </div>
</div>
</body>
</html>
"""

PROGRAM_BOX = """
            <div class="box{0}">
                <div class="box">
                    <p><strong>{1}</strong></p>
                    <a href="{2}" target="_blank" class="smallbutton">Log</a>
                    <a href="{3}" target="_blank" class="smallbutton">Bin</a>
                    <a href="{4}" target="_blank" class="smallbutton">Config</a>
                </div>
            </div>
"""
