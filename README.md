# WWW::EchoNest
Perl modules for accessing The Echo Nest web API. Read more about the Echo Nest at http://the.echonest.com.

INSTALLATION
--------------------

#### Prerequisites
 - Working internet connection for running the tests.  
 - Echo Nest API key (go to http://developer.echonest.com to get one, then see
     CONFIGURATION).
 - JSON CPAN module (and JSON::XS for speed!) for parsing Echo Nest responses.  

#### Recommended CPAN modules
 - Log::Log4perl if you want to log to a file instead of STDERR.  
 - File::Which if you want to use WWW::EchoNest::Song::identify -- see ECHOPRINT below.  

To install this module, run the following commands:

    $ perl Build.PL  
    $ ./Build  
    $ ./Build test  
    $ ./Build install  

You may see a warning during install:

> Could not read ECHO_NEST_API_KEY env var.  
> Your api key may need to be hardcoded into WWW/EchoNest/Preferences.pm.  

This probably means that you're installing by temporarily logging in as superuser
(i.e. by using the 'sudo' command) and that the superuser account doesn't have an
ECHO_NEST_API_KEY variable defined in their environment. You won't see during
normal usage as long as you set up the aforementioned environment variable for
your user account. See CONFIGURATION below for instructions on how to do this.

CONFIGURATION
--------------------
You *must* configure WWW::EchoNest to be able to see your developer API key.  
The easy way to do this is by setting an environment variable called
ECHO_NEST_API_KEY.  

    ECHO_NEST_API_KEY='ABC123';  
    export ECHO_NEST_API_KEY;  

Put this in your shell initialization script (e.g. ~/.profile) and you can
probably forget that you ever had to set up an API key!  

The hard way to do this is by using a function called set_api_key.  
This function is exported by WWW::EchoNest when you use the ':all' import tag.  

```perl
use WWW::EchoNest qw(:all);  
set_api_key('ABC123');  
```

USAGE
--------------------
```perl
use WWW::EchoNest qw(:all);
my $godfather = get_artist('James Brown');
my @audio_list      = $godfather->get_audio( { results => 50 } );
my @biography_list  = $godfather->get_biographies(); # Gets 15 results by default

my $free_bird = get_song('Free Bird');
my $free_bird_id = $free_bird->get_id();
my $free_bird_hotttnesss = $free_bird->get_song_hotttnesss();
```

ECHOPRINT
--------------------

The Echo Nest has released an open-source audio analyzer called 'echoprint'.
If you wish to use the WWW::EchoNest::Song::identify function then you will have to have echoprint installed and working properly on your system.
See http://echoprint.me for more information.
After getting echoprint up and running, you should either edit WWW/EchoNest/Config.pm to hardcode the 'codegen_binary_override' field or call set_codegen_path from any programs that use Song::identify.  

```perl
use WWW::EchoNest qw( set_codegen_path );
use WWW::EchoNest::Song qw( identify );
my $song = identify( { filename => 'path/to/audio_file.mp3' } );
```

#### Other requirements

 - Install ffmpeg. (See http://ffmpeg.org)  
 - Install File::Which from CPAN. (This is how WWW::EchoNest finds the location of ffmpeg, which you must have installed before using Song::identify.)

SUPPORT AND DOCUMENTATION
--------------------

After installing, you can find documentation for this module with the perldoc command.

    $ perldoc WWW::EchoNest

LICENSE AND COPYRIGHT
--------------------

Copyright (C) 2011 Brian Sorahan

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.
