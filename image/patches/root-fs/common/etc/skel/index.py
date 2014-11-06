#!/usr/bin/env python
# -*- coding: UTF-8 -*-

import os

PATH_PROGRAMS = os.path.join('/', 'home', 'tf', 'programs')
PATH_CONFIG   = os.path.join(PATH_PROGRAMS, '{0}', 'program.conf')
PATH_LOG      = os.path.join(PATH_PROGRAMS, '{0}', 'log')
PATH_BIN      = os.path.join(PATH_PROGRAMS, '{0}', 'bin')

def get_program_ids():
    try:
        return os.listdir(PATH_PROGRAMS)
    except:
        return []

def read_name_from_config(config):
    with open(config, "r") as f:
        for line in f:
            if line.startswith('custom.name ='):
                return line.replace('custom.name =', '').replace('\n', '').strip()

    return "Unknown Name"

def index(req):
    infos = {}
    for i in get_program_ids():
        infos[i] = {}
        path_config = PATH_CONFIG.format(i)
        infos[i]['name'] = read_name_from_config(path_config)
        infos[i]['url_config'] = os.path.join('/', 'programs', i, 'program.conf')
        infos[i]['url_log'] = os.path.join('/', 'programs', i, 'log')
        infos[i]['url_bin'] = os.path.join('/', 'programs', i, 'bin')

    boxnum = ['A', 'B', 'C']
    boxes = ''
    for i, info in enumerate(sorted(infos.values())):
        boxes += PAGE_BOX.format(boxnum[i % 3], info['name'], info['url_log'], info['url_bin'], info['url_config'])

    return PAGE.format(str(len(infos)), boxes)




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
    <div id="extra" class="container">
        <div class="title">
            <h2>Programs</h2>
            <span class="byline">Currently there are <strong>{0}</strong> programs running on the RED Brick</span> 
        </div>
        <p>
            For each program you can view the config, the logs and the binaries. If you uploaded an
            <strong>index.py</strong>, <strong>index.php</strong> or <strong>index.html</strong> 
            the respective file will be used as directory index for the binary folder.
        </p>
        <p>
            Example: If you want to write a PHP website that controls Bricks/Bricklets you can
            upload your program <strong>EXAMPLE</strong> with id <strong>EXAMPLEID</strong> that 
            includes an index.php as starting point. If you now go to this webpage and click on
            the "Bin" button for the newly created program, you will get a link to 
            <strong>/programs/EXAMPLEID/bin</strong>, which will directly execute the index.php
            if opened.
        </p>
        <div id="three-column">
{1}
        </div>
    </div>
</div>
</body>
</html>
"""

PAGE_BOX = """
            <div class="box{0}">
                <div class="box">
                    <p><strong>{1}</strong></p>
                    <a href="{2}" class="smallbutton">Log</a>
                    <a href="{3}" class="smallbutton">Bin</a>
                    <a href="{4}" class="smallbutton">Config</a>
                </div>
            </div>
"""
