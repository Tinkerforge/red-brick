#!/usr/bin/env python
# -*- coding: UTF-8 -*-

from flask import Flask, request # Use Flask framework
application = Flask(__name__)    # Function "application" is used by Apache/WSGI
app = application                # Use shortcut for routing

import os
import cgi

PATH_PROGRAMS = os.path.join('/', 'home', 'tf', 'programs')
PATH_OPENHAB = os.path.join('/', 'etc', 'openhab', 'configurations', 'sitemaps')

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

def get_openhab_sitemaps():
    try:
        return [c for c in os.listdir(PATH_OPENHAB) if c.endswith('.sitemap') and c != '.sitemap']
    except:
        return []

@app.route('/')
def index():
    program_infos = {}
    for i in get_program_ids():
        program_infos[i] = {}
        program_infos[i]['name'] = get_program_name(os.path.join(PATH_PROGRAMS, i, 'program.conf'))
        program_infos[i]['url_config'] = os.path.join('/', 'programs', i, 'program.conf')
        program_infos[i]['url_log'] = os.path.join('/', 'programs', i, 'log')
        program_infos[i]['url_bin'] = os.path.join('/', 'programs', i, 'bin')

    openhab_infos = {}
    for s in get_openhab_sitemaps():
        openhab_infos[s] = {}
        openhab_infos[s]['name'] = s[:-len('.sitemap')]
        openhab_infos[s]['url_sitemap'] = 'http://{0}:8080/openhab.app?sitemap={1}'.format(request.host, s[:-len('.sitemap')])

    box_num = ['A', 'B', 'C']
    program_boxes = ''
    for i, program_info in enumerate(sorted(program_infos.values())):
        program_boxes += PROGRAM_BOX.format(box_num[i % 3],
                                            cgi.escape(program_info['name']),
                                            program_info['url_log'],
                                            program_info['url_bin'],
                                            program_info['url_config'])

    openhab_boxes = ''
    for i, openhab_info in enumerate(sorted(openhab_infos.values())):
        openhab_boxes += OPENHAB_BOX.format(box_num[i % 3],
                                            cgi.escape(openhab_info['name']),
                                            openhab_info['url_sitemap'])

    if os.path.isfile('/etc/tf_server_monitoring_enabled'):
        nagios_status = 'enabled'
    else:
        nagios_status = 'disabled'

    return PAGE.format(len(program_infos),
                       program_boxes,
                       len(openhab_infos),
                       openhab_boxes,
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
                <li><a href="http://www.tinkerforge.com/en/doc/Hardware/Bricks/RED_Brick.html" class="button">RED Brick Documentation</a></li>
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
            <span class="byline">Currently there are <strong>{2}</strong> openHAB configurations available on the RED Brick</span>
        </div>
        <p>
            For each configuration you can view the sitemap. New configurations can be added and existing ones can be edited and deleted
            using the openHAB settings tab of Brick Viewer.
        </p>
        <div id="three-column">
{3}
        </div>
    </div>
    <div id="servermonitoring" class="container">
        <div class="title">
            <h2>Server Monitoring</h2>
            <span class="byline">Currently this service is <strong>{4}</strong> on the RED Brick</span>
        </div>
        <p>
            Monitoring rules for different Bricklets can be configured using the server monitoring settings tab of Brick Viewer.
            For more advanced configurations you can directly access the Nagios configuration web interface using the link below.
            The default username is <strong>nagiosadmin</strong> and the default password is <strong>tf</strong>.
        </p>
        <ul class="actions">
            <li><a href="/nagios" class="smallbutton">Nagios Status and Configuration</a></li>
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
                    <a href="{2}" class="smallbutton">Log</a>
                    <a href="{3}" class="smallbutton">Bin</a>
                    <a href="{4}" class="smallbutton">Config</a>
                </div>
            </div>
"""

OPENHAB_BOX = """
            <div class="box{0}">
                <div class="box">
                    <p><strong>{1}</strong></p>
                    <a href="{2}" class="smallbutton">Sitemap</a>
                </div>
            </div>
"""
