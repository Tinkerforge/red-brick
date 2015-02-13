#!/usr/bin/env python2
# -*- coding: UTF-8 -*-

from flask import Flask, request # Use Flask framework
from time import time            # Use time to get current Unixtime
from os import mkdir             # Use mkdir to create /tmp/sync-time

application = Flask(__name__)    # Function "application" is used by Apache/wsgi
app = application                # Use shortcut for routing

PAGE = """
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<title>Synchronize Date/Time</title>
</head>
<body>
<p id="local"><strong>Local:</strong> Getting...<p>
<p id="redbrick"><strong>RED Brick:</strong> Getting...<p>
<input type="hidden" id="timestamp" name="timestamp" value=""/>
<input type="hidden" id="timezone" name="timezone" value=""/>
<input type="submit" id="synchronize" value="Synchronize"/>
<div style="width: 500px">
<p><strong>Note 1:</strong> The RED Brick date and time is always displayed in
the local timezone, even if a different timezone is actually configured on the
RED Brick. This is caused by JavaScript not being able to format a given date
and time for an arbitrary timezone.<p>
<p><strong>Note 2:</strong> Even after a successful synchronization the date
and time might still differ by one or two seconds, this is due to the time it
takes to perform the synchronization itself.<p>
</div>
</body>
<script src="./jquery.js"></script>
<script>
function update() {
    var local = new Date();

    $('#local').html('<strong>Local:</strong> ' + local.toString());
    $('#timestamp').val(local.getTime());
    $('#timezone').val(local.getTimezoneOffset());

    $.ajax({
        url: 'index.py/get',
        type: 'GET',
        success: function(timestamp) {
            var redbrick = new Date();

            redbrick.setTime(parseInt(timestamp));

            // FIXME: JavaScript can only format in the local or UTC timezone. there
            //        is no build-in way to format in a specifc a timezone. therefore,
            //        the RED Brick time will be formatted in the local timezone,
            //        ignoring the actual timezone of the RED Brick.
            $('#redbrick').html('<strong>RED Brick:</strong> ' + redbrick.toString());
        }
    });
}

update();
setInterval(update, 1000);

$("#synchronize").click(function() {
    // increase timestamp by one second to try to compensate for the time it
    // take to perform the synchronization
    var timestamp = (parseInt($('#timestamp').val()) + 1000).toString();
    var timezone = $('#timezone').val();

    $.ajax({
        url: 'index.py/set?timestamp=' + timestamp + '&timezone=' + timezone,
        type: 'POST'
    });
});
</script>
</html>
"""

@app.route('/')
def index():
    return PAGE

@app.route('/get')
def get():
    return str(int(time() * 1000.0)) # JavaScript timestamp is in milliseconds

@app.route('/set', methods=['POST'])
def set():
    if 'timestamp' in request.args and 'timezone' in request.args:
        try:
            mkdir('/tmp/sync-time', 0777)
        except OSError:
            pass

        with open('/tmp/sync-time/set', 'wb') as f:
            f.write(request.args['timestamp'] + ' ' + request.args['timezone'] + '\n')

    return ''
