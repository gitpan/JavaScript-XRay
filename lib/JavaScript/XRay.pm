package JavaScript::XRay;
use warnings;
use strict;

=head1 NAME

JavaScript::XRay - See What Your JavaScript is Doing

=head1 VERSION

Version 0.9

=cut

our $VERSION = '0.9';
our $PACKAGE = __PACKAGE__;

=head1 SYNOPSIS

I put the comments in for lazy folks like myself who cut and 
page the Synopsis before they throughly read the pod.

 # HTML page with a <body> tag and hopefully some JavaScript
 # if you're using this module :)

 $html_page = "<html><head></head><body></body></html>";
 
 # the 'alias' is the prefix which all your switches will be 
 # prefixed with and helps "scope" the injected JavaScript
 # variables and functions so they don't collide with 
 # anything in your page.

 my $alias = 'jsxray';    # jsxray is the default

 # switches is just a hash ref that could be build for 
 # incoming parameters on a query string or passed 
 # via options via a command line script

 # In the future, hooks may be built for building the 
 # switches for popular frameworks.  The idea is that you
 # want to look through the incoming param list and pass
 # anything that matches your alias.  This interface isn't
 # the cleanest, but just wanted to make it generic.  It
 # can definately be improved...

 # via CGI.pm

 # my $q = CGI->new;
 # my $switches = { 
 #     map  { $_ => $q->param($_) }
 #     grep { /^$alias/ } $q->param
 # };

 # via mod_perl

 #  my $req = Apache::Request->new($r);
 #  my $switches = { 
 #    map { $_ => $req->param($_) } 
 #    grep { /^$alias/ } $req->param
 # };

 # or just hard coded to get something to work

 my $switches = { $alias => 1 };

 # or if you only one to see functions matching '/^ajax/'

 my $switches = { $alias => 1, $alias . "_filter" => 'ajax' };

 # now we only want to filter if its turned on so we can 
 # you may want put your switch building inside this 
 # conditional as well and just check for your alias 

 if ( $switches->{$alias} == 1 ) {
     my $js_xray = JavaScript::XRay->new(
         alias    => $alias,
         switches => $switches,
     );
     $html_page = $js_xray->filter($html_page);
 }

=head1 DESCRIPTION

JavaScript::XRay is an HTML source filter.  It was developed as
a tool to help figure out and debug large JavaScript frameworks.  

The main idea is that you hook it into your application framework
and give you the ability to 'flip a switch' an inject a JavaScript
function tracing console into your out going page.


=head2 Some of the things it does...

=over 4

=item * Injects a IFrame "log"

It finds the body tag in the document and injects the IFrame just after it
along with all the JavaScript to drive it.  It also provides you with a method
(whatever you used as alias - defaulted to jsxray).  

   jsxray("Hi there");

=item * Scans HTML for JavaScript functions

For each function it finds it inserts inserts a call to this method which logs the function call along with the value of the function arguments.

    function sum ( x, y ) {

becomes 

    function sum ( x, y ) {
        jsxray( "sum( " + x + ", " + y + " )" );

so now any call this this function and its arguments will get logged 
to the IFrame.

=item * Switches to limit what you log

You can manually B<skip> specific functions, choose to see B<only>
functions you specify, or B<filter> functions matching a specified
string. ( see L<SWITCHES> )

=item * Provide execution counts

Provides a method to see how often your functions are being called.  This can
be helpful to target which functions to rewrite to increase performance.

=item * Save the log for later.

You can cut and paste the IFrame to a text file to analyze later by hand 
or munge the results with perl.  Extremely helpful in moments when you 
have a lot of code executing and your just trying to get a handle on
what's happening.

=back

=head1 SWITCHES

The module's initial design was for it to be used via a query string
and the switches evolved from there.  (In other words, if this switch 
interface feels clunky, thats the reason why)

Also not the below examples use the alias 'jsxray' but if you use
a custom alias, the urls with change accordingly.

=over 4

=item * uncomment

Uncomment lines prefix with these strings (string1,string2)
Helpful with injecting timing code, or more specific 
debugging code.  You can deploy commented logging code to production
and turn it on when your turn on filtering.  Extremly helpful when 
diagnosing problems you can't reproduce in your development 
environment.

    http://someurl/somepage?jsxray=1&jsxray_uncomment=DEBUG1,DEBUG2

will uncomment

    //DEBUG1 jsxray("Hey this is debug1");
    //DEBUG2 jsxray("Hey this is debug2");

=item * anon  (bool)

Include filtering of anonymous functions. (bool)

    http://someurl/somepage?jsxray=1&jsxray_anon=1

=item * no_exec_count

Don't inject code that keeps track of how many times a function was called. 
(bool)

    http://someurl/somepage?jsxray=1&jsxray_no_exec_count=1

=item * only 

Only filter comma seperated list of functions (function1,function2,...)

    http://someurl/somepage?jsxray=1&jsxray_only=processData,writeTopage

=item * skip

Skip comma seperated list of functions (function1,function2,...)

    http://someurl/somepage?jsxray=1&jsxray_skip=formatNumber

=item * skip

Only filter function that match string (/^string/)

    http://someurl/somepage?jsxray=1&jsxray_filter=ajax


=back

=cut 

our %SWITCHES = (
    anon => {
        type => "bool",
        desc => "trace anon functions (noisy)",
    },
    no_exec_count => {
        type => "bool",
        desc => "don't count function executions",
    },
    only => {
        type => "function1,function2,...",
        desc => "only trace listed functions (exact)",
    },
    skip => {
        type => "function1,function2,...",
        desc => "skip listed functions (exact)",
    },
    uncomment => {
        type => "string1,string2,...",
        desc => "uncomment lines prefixed with string (DEBUG1,DEBUG2)",
    },
    filter => {
        type => "string",
        desc => "only trace functions that match string (/^string/)",
    },
);

our @SWITCH_KEYS = keys %SWITCHES;

=head1 CONSTRUCTOR

=head2 new

Create a new instance with the following arguments

=over 4

=item * alias

Think of this as a JavaScript namespace.  All injeted JavaScript fuctions 
and varibles are prefixed with this B<alias> to avoid colliding with 
any code that currently exists on your page.  It also is the prefix used for
all the switches to toggle things on and off.

=item * switches

Hash reference containing switches to change filtering behavor.  See the 
L</"Switches"> section for more details.

=item * iframe_height

The height of your logging IFrame, defaults to 200 pixels.

=item * css_inline

Change the style of the logging IFrame via inline CSS.

=item * css_external

Change the style of the logging IFrame via an external stylesheet.

=back

=cut

sub new {
    my ( $class, %args ) = @_;

    my $alias = $args{alias} || 'jsxray';
    my $obj = {
        alias            => $alias,
        iframe_height    => $args{iframe_height} || 200,
        switches         => _init_switches( $args{switches}, $alias ),
        css_inline       => $args{css_inline},
        css_external     => $args{css_external},
        js_log           => "",
        js_log_init      => "",
    };

    return bless $obj, $class;
}

=head1 METHODS

=head2 filter

=cut

sub filter {
    my ( $self, $html ) = @_;

    my ( $alias, $switch ) = ( $self->{alias}, $self->{switches} );

    my $use_ref  = ref $html;
    my $html_ref = $use_ref ? $html : \$html;

    my $ANON                = $switch->{anon};
    my %ONLY_FUNCTION       = map { $_ => 1 } split( /\,/, $switch->{only} );
    my %SKIP_FUNCTION       = map { $_ => 1 } split( /\,/, $switch->{skip} );
    my $ONLY_FUNCTIONS_BOOL = scalar keys %ONLY_FUNCTION;
    my $FUNCTION_FILTER     = quotemeta $switch->{filter} || "";

    my %UNCOMMENT_PREFIX
        = map { quotemeta($_) => 1 } split( /\,/, $switch->{uncomment} );

    $self->_warn( "Tracing anonymous subroutines" )
        if $ANON && !$ONLY_FUNCTIONS_BOOL;

    $self->_warn( "Only tracing functions exactly matching: $switch->{only}" )
        if $ONLY_FUNCTIONS_BOOL;

    $self->_warn( "Skipping functions: $switch->{skip}" )
        if keys %SKIP_FUNCTION;

    $self->_warn( "Tracing matching functions: /^$FUNCTION_FILTER/" )
        if $FUNCTION_FILTER;

    for my $uncomment ( keys %UNCOMMENT_PREFIX ) {
        $self->_warn( "Uncommenting lines beginning with: //$uncomment" );
    }

    my $work_html = $$html_ref;
    my @new_lines = ();
    my @lines     = split( /\n/, $work_html );
    my $num       = @lines;

    $self->_warn( "Filtering $num lines of HTML" );

    my $line_num = 1;

    LINE:
    for my $line (@lines) {

        for my $uncomment ( keys %UNCOMMENT_PREFIX ) {
            my $uncomment_count = $line =~ s/\/\/$uncomment//g;
            $self->_warn("$PACKAGE->filter uncommented line $line_num")
                if $uncomment_count;
        }

        FUNCTION:
        for my $function ( $line =~ /(function?\s*\w+?\s*?\(.+?\)?\s*\{)?/g ) {
            next unless $function;

            my ($name) = $function =~ /function\s*(\w+?)?\s*?\(/g;
            $name = "" unless $name;  # define it to supress warnings

            # don't want any recursive JavaScript loops
            croak( "found function '$name' on line $line_num, functions may "
                    . "not match alias: '$alias'" )
                if $name eq $alias;

            my ($args) = $function =~ /function\s*$name?\s*?\((.+?)\)/g;
            $name = "ANON" unless $name;

            $self->{js_log_init} .= "${alias}_exec_count['$name'] = 0;\n"
                unless $switch->{no_exec_count};

            # skip anon functions if ALIAS_skip_anon
            next FUNCTION if $name eq "ANON" && !$ANON;
            next FUNCTION if $ONLY_FUNCTIONS_BOOL && !$ONLY_FUNCTION{$name};
            next FUNCTION if $SKIP_FUNCTION{$name};
            next FUNCTION if $FUNCTION_FILTER && $name !~ /^$FUNCTION_FILTER/;

            $self->_warn( "Found function '$name' at line $line_num" );

            # build out function arguments
            my $q_args = "";
            if ($args) {
                my @arg_list = split( /\,/, $args );
                $q_args = "'+" . join( "+', '+", @arg_list ) . "+'";
            }

            # make everything safe and insert the trace call
            my $q_function = quotemeta $function;
            my $q_function_replace = "";
            $q_function_replace .= $function; 
            $q_function_replace .= "$alias('$name( $q_args )');";
            $q_function_replace .= "${alias}_exec_count['$name']++;"
                unless $switch->{no_exec_count};
            $line =~ s/$q_function/$q_function_replace/;
        }
        $line_num++;
        push @new_lines, $line;
    }

    $work_html = join( "\n", @new_lines );
    $self->_inject_console( \$work_html );
    $self->_inject_js_css( \$work_html );

    return $use_ref ? \$work_html : $work_html;
}

=head1 INTERNAL METHODS

=head2 _inject_js_css

Hook to inject the alias prefixed JavaScript and CSS into the page.

=cut

sub _inject_js_css {
    my ( $self, $html_ref ) = @_;
    my ( $alias, $switches ) = ( $self->{alias}, $self->{switches} );

    my $js_css = qq|<script><!--
    var ${alias}_logging_on = true;
    var ${alias}_doc = null;
    var ${alias}_cont_div = null;
    var ${alias}_last_div = null;
    var ${alias}_count = 1;
    var ${alias}_exec_count = [];
    var ${alias}_date_start;
    var ${alias}_time_start;

    function ${alias}( msg ) {
        if ( !${alias}_logging_on ) return;
        if ( ${alias}_doc == null) ${alias}_init( "Initialized" );
        
        // timing data
        var ${alias}_date_now = new Date();
        var ${alias}_time_since = ${alias}_date_now.getTime();
        var ${alias}_elapsed_time = 
            ( ${alias}_time_since - ${alias}_time_start );
        var ${alias}_time = ${alias}_date_format( ${alias}_date_now );
        var ${alias}_div  = ${alias}_doc.createElement( 'DIV' );

        ${alias}_div.className = "${alias}_desc";
        ${alias}_doc.body.appendChild( ${alias}_div );
        ${alias}_cont_div.insertBefore(${alias}_div, ${alias}_last_div);
        ${alias}_div.innerHTML = "<span class='${alias}_loginfo'>[ " 
            + ${alias}_count + ' - ' + ${alias}_time + ' - ' 
            + ${alias}_elapsed_time + "ms ]</span> " + msg;
        ${alias}_count++;
        ${alias}_last_div = ${alias}_div;
    }

    function ${alias}_init(init_msg) {
        $self->{js_log_init}
        ${alias}_date_start = new Date();
        ${alias}_time_start = ${alias}_date_start.getTime();
        ${alias}_doc = window.frames.${alias}_iframe.document;
        ${alias}_doc.open();
        ${alias}_doc.write("<!DOCTYPE html PUBLIC -//W3C//DTD ");
        ${alias}_doc.write("XHTML 1.0 Transitional//EN ");
        ${alias}_doc.write("  http://www.w3.org/TR/xhtml1/DTD/");
        ${alias}_doc.write("xhtml1/DTD/xhtml1-transitional.dtd>\\n\\n");
        ${alias}_doc.write("<html><head><title>$PACKAGE v$VERSION");
        ${alias}_doc.write("</title>\\n");
        ${alias}_doc.write("</head>");
        ${alias}_doc.write("|;
   $js_css .= $self->_css(1);
   $js_css .= qq|");
        ${alias}_doc.write("<body style='");
        ${alias}_doc.write("background-color:white; margin: 2px'></body>\\n");
        ${alias}_doc.close();
        ${alias}_cont_div = ${alias}_doc.createElement( 'DIV' );
        ${alias}_doc.body.appendChild(${alias}_cont_div);
        ${alias}_last_div = ${alias}_doc.createElement( 'DIV' );
        ${alias}_last_div.className = "${alias}_desc";
        ${alias}_last_div.innerHTML = "<span class='${alias}_loginfo'>[ " 
            + ${alias}_count 
            + " - " 
            + ${alias}_date_format( ${alias}_date_start ) 
            + " - 0ms ]</span> $PACKAGE " + init_msg;
        ${alias}_cont_div.appendChild(${alias}_last_div);
        ${alias}_count++;
    }

    function ${alias}_alert_counts() {
        var msg = "";
        var sort_array = new Array;
        for ( var key in ${alias}_exec_count ) sort_array.push( key );
        sort_array.sort( ${alias}_exec_key_sort );
        for( var x = 0; x < sort_array.length; x++ ) {
             if ( ${alias}_exec_count[sort_array[x]] != 0 ) {
                 msg += sort_array[x] + " = " + ${alias}_exec_count[sort_array[x]] + "\\n";
             }
        }
        alert(msg);
    }

    function ${alias}_exec_key_sort( a, b ) {
        var x = ${alias}_exec_count[b];
        var y = ${alias}_exec_count[a];
        return ( ( x < y) ? -1 : ( (x > y) ? 1 : 0 ) );
    }

    function ${alias}_date_format ( date ) {
        var ${alias}_day   = date.getDate();
        var ${alias}_month = date.getMonth() + 1;
        var ${alias}_hours = date.getHours();
        var ${alias}_min   = date.getMinutes();
        var ${alias}_sec   = date.getSeconds();
        var ${alias}_ampm  = "AM";

        if ( ${alias}_hours > 11 ) ${alias}_ampm = "PM";
        if ( ${alias}_hours > 12 ) ${alias}_hours -= 12;
        if ( ${alias}_hours == 0 ) ${alias}_hours = 12;
        if ( ${alias}_min < 10 )   ${alias}_min = "0" + ${alias}_min;
        if ( ${alias}_sec < 10 )   ${alias}_sec = "0" + ${alias}_sec;

        return ${alias}_month + '/' + ${alias}_day + ' ' 
            + ${alias}_hours  + ':' + ${alias}_min + ':'
            + ${alias}_sec    + ' ' + ${alias}_ampm;
    }

    function ${alias}_toggle_info() {
        var info = ${alias}_gel( '${alias}_info' )
        if ( !info ) return;
        var info_button = ${alias}_gel( '${alias}_info_button' )
        if ( !info_button ) return;
        if ( info.style.display == '' ) {
            info.style.display = 'none';
            info_button.value = "Show Info";
        }
        else {
           info.style.display = '';
            info_button.value = "Hide Info";
        }
    }

    function ${alias}_clear() {
        if ( !confirm("Are you sure?") ) return;
        ${alias}_count = 1;
        ${alias}_init( "Console - Cleared" );
    }

    function ${alias}_toggle_logging() {
        var logging_button = ${alias}_gel( '${alias}_logging_button' )
        if ( !logging_button ) return;
        if ( ${alias}_logging_on ) {
           ${alias}("$PACKAGE Console Stopped Logging");
            logging_button.value = "Resume Logging";
            ${alias}_logging_on = false;
        }
        else {
           ${alias}_logging_on = true;
           logging_button.value = "Stop Logging";
           ${alias}("$PACKAGE Console - Resumed Logging");
        }
    }

    function ${alias}_gel( el ) {
        return document.getElementById ? document.getElementById( el ) : null;
    }

    -->
    </script>\n|;
    $js_css .= $self->_css;

    $$html_ref =~ s/(<head.*?>)/$1$js_css/is;
}

=head2 _inject_console

Hook to inject HTML and the IFrame into the page.

=cut

sub _inject_console {
    my ( $self, $html_ref ) = @_;

    my ( $alias, $switches ) = ( $self->{alias}, $self->{switches} );

    my $iframe .= qq|
    <div class='${alias}_buttons' id='${alias}_buttons'>
    <span class="${alias}_version">$PACKAGE v$VERSION</span>
    <input type="button" value="Stop Logging" id="${alias}_logging_button" 
        onClick="${alias}_toggle_logging()" class="${alias}_button">
    <input type="button" value="Show Info" id="${alias}_info_button" 
        onClick="${alias}_toggle_info()" class="${alias}_button">
    <input type="button" value="Clear" onClick="${alias}_clear()" 
        class="${alias}_button">|;

    $iframe .= qq| <input type="button" value="Execution Counts" 
        onClick="${alias}_alert_counts()" class="${alias}_button">|
        unless $switches->{no_exec_count};

   $iframe .= qq|</div>
    <div id="${alias}_info" class="${alias}_buttons" style='display:none'>
    <center>
    <table cellpadding=0 cellspacing=0 border=0>|;

    for my $switch ( @SWITCH_KEYS ) {
        my $value = $switches->{$switch} || "";
        $iframe .= qq|<tr>
                <td class='${alias}_desc'>${alias}_$switch</td>
                <td>&nbsp;&nbsp;</td>
                <td class='${alias}_value'>$value</td>
                <td class='${alias}_desc'>$SWITCHES{$switch}{type}</td>
                <td>&nbsp;&nbsp;</td>
                <td class='${alias}_desc'>$SWITCHES{$switch}{desc}</td>
            </tr>|;
    }

    $iframe .= qq|
    </table>
    </center>
    </div>
    <div class="${alias}_iframe_padding">
    <div class="${alias}_iframe_border">
    <iframe id="${alias}_iframe" name="${alias}_iframe" class="${alias}_iframe"></iframe>
    </div>
    </div>
    <script>
    $self->{js_log}
    </script>|;

    $$html_ref =~ s/(<body.*?>)/$1$iframe/is;
}

=head2 _css

Hook to inject alias prefixed CSS into the iframe and page.

=cut

sub _css {
    my ($self, $escape_bool) = @_;

    my ($alias) = ($self->{alias});

    my $css = qq|<style>
    .${alias}_desc, td.${alias}_value, .${alias}_loginfo, ${alias}_buttons {
        font-family: arial,helvetica; 
        font-size: 12px; 
        background-color: white;
    }
    td.${alias}_desc, td.${alias}_value, .${alias}_buttons {
        background-color: #D3D3D3
    }
    td.${alias}_desc, td.${alias}_value, .${alias}_version {
        font-size: 12px; 
    }
    .${alias}_buttons { 
        padding-top: 4px; 
        padding-left: 8px; 
        padding-bottom: 4px; 
    }
    .${alias}_loginfo, .${alias}_version, .${alias}_buttons {
        color: #727272
    }
    td.${alias}_value {
        color: #5555FF;
        padding-left:1em;
        padding-right:1em;
    }
    .${alias}_version {
        font-family: arial,helvetica; 
        float:right;
        padding-right: 10px;
    }
    .${alias}_iframe_padding {
        border-width: 0px 7px 7px 7px;
        border-color: #D3D3D3;
        border-style: solid;
    }
    .${alias}_iframe_border {
        border-width: 1px;
        border-style: groove;
    }
    .${alias}_iframe {
        width: 100%;
        height: $self->{iframe_height}px;
        border: 0px;
    }
    input.${alias}_button {
        background-color: #D3D3D3;
        border-width: 1px;
        border-color: #a9a9a9;
    }|;

    # cat inline css
    $css .= $self->{css_inline} if $self->{css_inline};
    $css .= qq|\n</style>\n|;

    # include external file
    $css .= qq|<link href="self->{css_external}" rel="stylesheet" |
        . qq|type="text/css" />\n|
        if $self->{css_external};

    if ($escape_bool) {
        $css =~ s/\n/\\n/sg;
        $css =~ s/\"/\\\"/g;
    }

    return $css;
}

=head2 _init_switches

Take alias prefixed switched passed in and strip off the alias
and make them easier to call.

=cut

sub _init_switches {
    my ( $raw_switch, $alias ) = @_;

    my $alias_length = length($alias) + 1;
    my $switch = {
        map  { $_->[0] => ( $raw_switch->{ $_->[1] } || "" ) } 
        map  { [ substr( $_, $alias_length ), $_ ] }
        grep {/^${alias}_/}
        keys %$raw_switch
    };
    
    # init other switches so we don't get warnings
    for my $switch_name ( @SWITCH_KEYS ) {
        $switch->{$switch_name} = "" unless exists $switch->{$switch_name};
    }

    return $switch;
}

=head2 _warn

Hook to warn to the JavaScript IFrame log.

=cut

sub _warn {
    my ( $self, $msg ) = @_;

    my $alias = $self->{alias};
    $self->{js_log} .= qq|$alias("${PACKAGE}-&gt;filter $msg");\n|;
}

=head1 AUTHOR

Jeff Bisbee, C<< <jbisbee at cpan.org> >>

=head1 TODO

Some of the things that are still in the conceptional phase

=over 4

=item * Inlining external JavaScript files

The biggest short coming of this module is that fact that it doesn't process
external JavaScript files :(  I have a couple of ways to do this in mind
but want not of them are elegant.  I figured I just release the module first
and see what ideas other folks and come up with a solution.

=item * Personal proxy

Include a personal proxy script with this module so you can filter 
ANY webpage you go to.

=item * Command line filter

Include a command line script that will just filter HTML file from the 
command line.  This way you just save a page with your browser and you 
can filter it if you want.  ( excellent for reverse engineering)

=item * Add a user interface to the console to control the switches

Add a form to the console that will allow you to see the values of the
switches and then resubmit the url to have the changes take affect.

=back

=head1 BUGS

Please report any bugs or feature requests to
C<bug-JavaScript-xray at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=JavaScript-XRay>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc JavaScript::XRay

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/JavaScript-XRay>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/JavaScript-XRay>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=JavaScript-XRay>

=item * Search CPAN

L<http://search.cpan.org/dist/JavaScript-XRay>

=back

=head1 ACKNOWLEDGEMENTS

=over 4

=item * Senta Mcadoo

Providing the JavaScript DOM logging code in order to do the reverse logging
(solved the scrolling problem).

=item * Ronnie Paskin

General hacking on the code, good feedbak, and for being a sounding board to
work out issues.

=item * Tony Fernandez

Giving me the green light to publish this on the CPAN.

=back

=head1 COPYRIGHT & LICENSE

Copyright 2006 Jeff Bisbee, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;