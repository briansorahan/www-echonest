
package WWW::EchoNest::Util;

use 5.010;
use strict;
use warnings;
use Carp;
use Encode;
use Config;
use Digest::MD5 qw( md5_hex );
use URI;
use URI::Escape;
use LWP::UserAgent;
use HTTP::Request::Common;
use HTTP::Response;
use JSON;

use WWW::EchoNest;
our $VERSION = $WWW::EchoNest::VERSION;

use WWW::EchoNest::Config;
use WWW::EchoNest::Logger;

BEGIN {
    our @EXPORT        = qw[ ];
    our @EXPORT_OK     = qw[
                               call_api
                               codegen
                               fix_keys
                               user_agent
                               json_rep
                               md5
                          ];
    our %EXPORT_TAGS   =
        (
         all => [ @EXPORT_OK ],
        );
}
use parent qw[ Exporter ];



########################################################################
#
# MD5 generator
#
sub md5 {   return md5_hex( $_[0] )   }



########################################################################
#
# Configuration
#
{
    my $conf = WWW::EchoNest::Config->new();

    sub get_conf {   return $conf   }

    # Expects a hash ref of parameters to be passed to the WWW::EchoNest::Config
    # constructor
    sub set_conf {   $conf = WWW::EchoNest::Config->new( $_[0] )   }
}



########################################################################
#
# Set up a JSON pretty-printer
#
sub json_rep {
    my $json = JSON->new->utf8->pretty();
    return $json->encode( $_[0] )
}



# Set up the HTTP User Agent
{
    my $logger           = get_logger;
    my $user_agent       = LWP::UserAgent->new();
    my $trace_api_calls  = get_conf()->get_trace_api_calls;
    
    _set_timeout( get_conf()->get_timeout() );
    
    my @headers = ( 'User-Agent' => get_conf()->get_user_agent() );

    my $request_handler = sub {
        $logger->info( 'uri: '
                       . $_[0]->uri  . "\n"
                       . 'request: ' . $_[0]->dump . "\n"
                       . 'timeout: ' . user_agent()->timeout() . "\n"
                     ) if $trace_api_calls;
    };

    my $response_handler = sub {
        $logger->info(
                      $_[0]->is_success ? 'success' : 'failed'  . "\n"
                      . $_[0]->dump . "\n"
                     ) if $trace_api_calls;
    };

    $user_agent->env_proxy;
    $user_agent->default_header( @headers );
    $user_agent->show_progress(1) if get_conf->get_show_progress();
    $user_agent->add_handler(
                             request_prepare   => $request_handler,
                             response_done     => $response_handler,
                            );

    sub user_agent     {   return $user_agent              }
    sub _set_timeout   {   $user_agent->timeout( $_[0] )   }
}

########################################################################
#
# Inputs a JSON string encoded in Perl's internal encoding
# and returns a hash ref constructed from the string.
# Croaks on error.
#
{
    # Formats a string generated by an Echo Nest API Error
    my $api_error = sub {
        my($code, $message) = @_;
        return "Echo Nest API Error: $code, $message";
    };

    sub _get_successful_response {
        my $logger = get_logger();
        
        my($raw_json) = @_;
        my $trace_api_calls = get_conf()->get_trace_api_calls();

        # Ensure that the JSON string is UTF-8 encoded
        eval {
            $raw_json = encode("UTF-8", $raw_json);
        };
        croak qq/$@/ if $@;
    
        # Decode it into a hash ref
        my $response_ref;
        eval {
            $response_ref = decode_json( $raw_json );
        };
        croak "Error decoding JSON: $@" if $@;

        $logger->info( 'response: ' . json_rep($response_ref) )
            if ($trace_api_calls);
                     
    
        # Fetch the status block, response code, and response message
        my $status_hash_ref    = $response_ref->{'response'}{'status'};
        my $response_code      = $status_hash_ref->{'code'};
        my $response_message   = $status_hash_ref->{'message'};
    
        # Croak if the response code indicates that something went wrong
        croak( $api_error->( $response_code, $response_message ) )
            if ($response_code != 0);
    
        # Delete the status block and return the hash ref
        delete $response_ref->{'response'}{'status'};
        return $response_ref;
    }
}

########################################################################
#
# Subroutines and variables associated with using an Echo Nest
# code generator.
#
# The test suite needs a way to be able to tell if the system is configured with
# a code generator. This code should be located in this module. I could make it
# so that the Build script will attempt to run the codegen on the test file within
# an 'eval' block, and then test $@ for failure to determine if there was an
# error running the codegen.
# -- bps [8.11.11]
#
{
    my $FFMPEG_NOT_FOUND_ERROR  = 'Could not find ffmpeg';
    my $CODEGEN_NOT_FOUND_ERROR = 'Could not find codegen binary';
    my $NO_FILE_WHICH_ERROR
        = 'You must install File::Which from CPAN to use the codegen';

    # The system call used for the codegen
    my $CODEGEN_CMD                  = q[];
    my $CODEGEN_CMD_CONSTRUCTED      = 0;

    # Returns a boolean value indicating whether or not the system is ready
    # to use the Echoprint (or ENMFP) codegen.
    # 
    # Requires:
    # - File::Which to be installed from CPAN.
    # - Echoprint (or ENMFP) to be installed.
    # - Absolute path to codegen binary set properly in WWW/EchoNest/Config.pm
    #
    # The output of this subroutine is run only once every time your program is
    # run.
    sub _get_codegen_cmd {
        return $CODEGEN_CMD if $CODEGEN_CMD_CONSTRUCTED;
        
        # my $logger = get_logger;

        # First we have to set the PATH env var to ffmpeg's location.
        # Users are required to install File::Which from CPAN to use this
        # feature.
        eval {
            use File::Which;
        };
        croak "$NO_FILE_WHICH_ERROR\n$@" if $@;
        
        # Find ffmpeg and set the PATH to its dir, so the codegen can use it.
        my $ffmpeg_location = which('ffmpeg');

        # codegen doesn't exist or isn't executable
        croak "$FFMPEG_NOT_FOUND_ERROR"  if not $ffmpeg_location;
        
        $ffmpeg_location    =~ s{(.*)/ffmpeg}{$1}; # For UNIX systems
        $ffmpeg_location    =~ s{(.*)\\ffmpeg\.exe}{$1}; # For Windows systems
        local $ENV{'PATH'};
        if ( $ffmpeg_location =~ m{([[:alpha:][:digit:]_./\\]+)} ) {
            $ENV{'PATH'} = $1;
        }

        my $cmd = get_conf()->get_codegen_binary_override();

        # Assuming the user has not entered the location of their
        # codegen binary in Config.
        if (! $cmd) {
           # Not quite sure what values $Config{osname} will have under
            # Mac and Windows (I'm coding on Linux)...
            my $osname = exists $Config{osname} ? $Config{osname} : $^O;

            if ( $osname =~ m{(?>mac|darwin)}i ) {
                $cmd = 'codegen.Darwin';
            } elsif ( $osname =~ m{win}i ) {
                $cmd = 'codegen.windows.exe';
            } else {            # linux
                if ( exists $Config{'archname'} ) {
                    my @arch_name_fields = split '-', $Config{'archname'};
                    $cmd = "codegen.${osname}-$arch_name_fields[0]";
                }
            }
        }

        # Croak if codegen doesn't exist
        croak "$CODEGEN_NOT_FOUND_ERROR: $cmd"  if ! -e $cmd;
        $CODEGEN_CMD = $cmd;
        $CODEGEN_CMD_CONSTRUCTED = 1;
        return $cmd;
    }

    # Call the codegen on a local file.
    sub codegen {
        my %args             = %{ $_[0] };

        my $filename         = $args{filename};
        my $start            = $args{start}       // 0;
        my $duration         = $args{duration}    // 30;
    
        # Quote filename for passing to subshell...
        $filename = qq['$filename'];
        my $cmd = _get_codegen_cmd();
        
        # Construct and untaint the command for pipe open
        my $command = "$cmd $filename $start $duration";
        if ( $command =~ /([[:alpha:][:punct:][:digit:][:space:]]+)/ ) {
            $command = $1;
        }
    
        # Run it and save the output
        open( my $codegen_out, "$command |" );
        my $codegen_output = q[];
        while (<$codegen_out>) {   $codegen_output .= $_ if ! /^TagLib.*$/;   }
    
        # Make sure the codegen output is UTF-8 encoded
        eval {
            $codegen_output = encode("UTF-8", $codegen_output);
        };
        croak $@ if $@;
        
        return $codegen_output;
        
        my $codegen_dsc;
        eval {
            $codegen_dsc = decode_json( $codegen_output );
        };
        carp $@ if $@;

        return $codegen_dsc;
    }
}

########################################################################
#
# Call the Web API.
# Single HASH-ref argument.
#
{
    # Message printed when an HTTP Request is unsuccessful
    my $HTTP_RESPONSE_FAILED = "Bad response: ";

    sub call_api {
        my %args = %{ $_[0] };

        my $logger = get_logger();

        # Extract some fields and delete them from %args
        my $method     =     delete $args{ q/method/  };
        my $timeout    =     delete $args{ q/timeout/ };
        my $post       =    (delete $args{ q/post/    }) // 0;

        _set_timeout($timeout) if $timeout;
    
        # POST data - can be ARRAY or HASH ref
        my $data       =    (delete $args{ q/data/    }) // [];

        # The hash that will be used to construct the query form
        my %params     =  %{ delete $args{ q/params/  } };
    
        # Fetch the WWW::EchoNest::Config constants
        my $api_host          = get_conf->get_api_host();
        my $api_selector      = get_conf->get_api_selector();
        my $api_version       = get_conf->get_api_version();
        my $trace_api_calls   = get_conf->get_trace_api_calls();
    
        # Set the api_key
        $params{api_key} = get_conf->get_api_key();

        # Initialize the parameter list
        my @param_list;
    
        # Build the parameter list from the args hash
        while ( my ($key, $value) = each %params ) {
            if ( ref $value eq 'ARRAY' ) {
                my @value_list = @$value;
            
                for ( @value_list ) {
                    my $utf8_value;
                    eval {
                        $utf8_value = encode_utf8($_) if defined($_);
                    };
                    croak "$@" if $@;
                    push @param_list, ($key, $utf8_value)
                        if defined($utf8_value);
                }
            } elsif (defined($value)) {
                my $utf8_value;
                eval {
                    $utf8_value = encode_utf8($value);
                };
                croak "$@" if $@;
                push @param_list, ($key, $utf8_value)
                    if defined($utf8_value);
            }
        }
    
        # Ensure that the strings in our parameter list are URI encoded
        # @param_list = map { uri_escape_utf8($_) } @param_list;
    
        my $response;
    
        if ($post) {
            # If this is a normal POST call...
            if (($method ne 'track/upload')
                || (($method eq 'track/upload') && (exists $params{'url'}))) {
            
                # Build the URL
                my $urlPOST = URI->new(
                                       'http://' . $api_host
                                       .     '/' . $api_selector
                                       .     '/' . $api_version
                                       .     '/' . $method
                                      );
	    
                # Build the form data...
                #
                # The fact that I had to write this if/else block means that
                # something is wrong about the way song/identify is using
                # the call_api function.
                if ($data and $method eq 'catalog/update') {
                    push @param_list, ( data => $data, );
                    my $request = POST(
                                       $urlPOST,
                                       Content_Type     => 'form-data',
                                       Content          => \@param_list
                                      );
                    $logger->debug( json_rep($data) )
                        if $trace_api_calls && ref($data);
                    $response = user_agent()->request( $request );
                } else {
                    push @param_list, @$data if ( ref($data) eq 'ARRAY' );
                    push @param_list, %$data if ( ref($data) eq 'HASH' );

                    $logger->debug( json_rep($data) )
                        if $trace_api_calls && ref($data);

                    if ($method eq 'catalog/delete') {
                        $response
                            = user_agent()->post(
                                                 $urlPOST,
                                                 Content_Type  => 'form-data',
                                                 Content       => \@param_list,
                                                );
                    } else {
                        $response = user_agent()->post( $urlPOST, \@param_list );
                    }
                }
            } else {
                # This calls method 'track/upload' with a local file,
                # and in this case the 'track' field of the form-ref
                # contains the audio data (which should be provided
                # in the 'data' field of the hash-ref that was passed
                # to this function).
                my $urlPOST
                    = URI->new(
                               'http://' . $api_host
                               .     '/' . $api_selector
                               .     '/' . $api_version
                               .     '/' . $method
                              );
            
                $urlPOST->query_form( \@param_list );
            
                my $request = POST
                    (
                     $urlPOST,
                     Content_Type    => 'application/octet-stream',
                    );
                
                if ($data) {
                    $request->add_content($data);
                } else {
                    carp 'No data';
                }
                
                $response = user_agent()->request($request);
            }
        } else {                # A GET request
            my $urlGET = URI->new(
                                  'http://' . $api_host
                                  .     '/' . $api_selector
                                  .     '/' . $api_version
                                  .     '/' . $method
                                 );
        
            $urlGET->query_form( \@param_list );
        
            # Log the URL if we have enabled TRACE_API_CALLS
            # $logger->info( q/GET / . $urlGET )    if ($trace_api_calls);

            $response = user_agent()->get( $urlGET );
        }
        return _get_successful_response( $response->decoded_content() );
    }
}

# Attempt to replace postMultipart() with nearly-identical interface.
# (The files tuple no longer requires the filename, and we only return
# the response body.) 
# Uses the urllib2_file.py originally from 
# http://fabien.seisen.org which was also drawn heavily from 
# http://code.activestate.com/recipes/146306/ .

# This urllib2_file.py is more desirable because of the chunked 
# uploading from a file pointer (no need to read entire file into 
# memory) and the ability to work from behind a proxy (due to its 
# basis on urllib2).
sub post_chunked {
    return;
}

# We need this to fix up all the dict keys to be strings,
# not unicode objects
sub fix_keys {
    my($hash_ref) = $_[0];
    
    if ( ref($hash_ref) ne 'HASH' ) {
        croak( q/single hashref argument required/ );
    }
    
    my %new_hash;
    while ( my($k, $v) = each %$hash_ref ) {
        # Encode::FB_Croak == 1 (according to the Encode documentation)
        # I tried investigating the value of Encode::FB_Croak by issuing the
        # command
        # perl -e 'use Encode; print $Encode::FB_Croak, "\n";'
        # and it printed a blank line.
        # This is why I have simply written a 1 as the third parameter
        # to decode().
	#
        # - bps 5.22.2011
	#
        $new_hash{ decode(q/UTF-8/, $k, 1) } = $v;
    }
    
    return \%new_hash;
}

1; # End of WWW::EchoNest::Util

__END__



=head1 NAME

WWW::EchoNest::Util - Utility functions to support the Echo Nest web API.



=head1 VERSION

Version 0.001.



=head1 DEPENDENCIES

=head2 CPAN

JSON



=head1 SYNOPSIS
    
    use WWW::EchoNest::Util;



=head1 METHODS

=head2 new

Returns a new WWW::EchoNest::Util instance.



=head1 FUNCTIONS

=head2 user_agent

  Returns the LWP::UserAgent instance used by all WWW::EchoNest classes for
  making HTTP requests.

=head2 json_rep

  Attempts to convert it's single argument into a JSON formatted string.

=head2 codegen

  Calls the codegen program and returns a HASH ref result.

=head2 call_api

  Calls the Echo Nest web API.

=head2 get_conf

  Returns the instance of WWW::EchoNest::Config used internally by Util.pm.

=head2 set_conf

  Creates a new WWW::EchoNest::Config object to be used internally by Util.pm.
  Accepts a single HASH ref argument.

=head2 post_chunked

  Calls the Echo Nest web API. This most important method
  of the entire WWW::EchoNest system.

=head2 fix_keys

  Calls the Echo Nest web API. This most important method
  of the entire WWW::EchoNest system.



=head1 AUTHOR

Brian Sorahan, C<< <bsorahan@gmail.com> >>

=head1 SUPPORT

Join the Google group: <http://groups.google.com/group/www-echonest>

=head1 ACKNOWLEDGEMENTS

Thanks to all the folks at The Echo Nest for providing access to their
powerful API.

=head1 LICENSE AND COPYRIGHT

Copyright 2011 Brian Sorahan.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.
