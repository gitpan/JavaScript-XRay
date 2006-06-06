#!perl -T

use Test::More tests => 4;

BEGIN { use_ok( 'JavaScript::XRay' ); }
require_ok( 'JavaScript::XRay' );

my $jsxray = JavaScript::XRay->new();

isa_ok( $jsxray, 'JavaScript::XRay' );

my $test_page = do { local $/; <DATA> };
my $xrayed_page = $jsxray->filter($test_page);
like( $xrayed_page, qr/jsxray/s, "Page Successfully Filtered" );

__DATA__
<html>
<head>
<script>
<!--

function gel( id ) {
    return document.getElementById ? document.getElementById(id) : null;
}

var timing = 0;
function start_stop_clock() {
    var button = gel('button');
    if (timing) {
        button.value = "Start Clock";
        window.clearInterval(timing);
        timing = 0;
    }
    else {
        button.value = "Stop Clock";
        timing = window.setInterval( "prettyDateTime()", 1000 );
    }
}

function prettyDateTime() {
    var time = gel('time');
    var date  = new Date;
    var day   = date.getDate();
    var month = date.getMonth() + 1;
    var hours = date.getHours();
    var min   = date.getMinutes();
    var sec   = date.getSeconds();
    var ampm  = "AM";

    if ( hours > 11 ) ampm = "PM";
    if ( hours > 12 ) hours -= 12;
    if ( hours == 0 ) hours = 12;
    if ( min < 10 )   min = "0" + min;
    if ( sec < 10 )   sec = "0" + sec;

    time.innerHTML = month + '/' + day + ' ' + hours  
        + ':' + min + ':' + sec    + ' ' + ampm;
}

-->
</script>
<title>Testing</title>
</head>
<body>
<table>
<tr>
    <td>
    <input id="button" type="button" value="Start Clock" onClick="start_stop_clock()">
    </td>
    <td id="time">&nbsp;</td>
</tr>
</table>
</body>
</html>
