
package WWW::EchoNest;

use 5.010;
use strict;
use warnings;
use Carp;

BEGIN {
    our $VERSION = '0.0.1';
    our @EXPORT    = ();
    our @EXPORT_OK =
        (
         # Convenience methods
         'get_artist',
         'get_catalog',
         'get_playlist',
         'get_song',
         'get_track',
         'pretty_json',
         'set_log_level',
         'set_codegen_path',
         'set_api_key',
        );
    our %EXPORT_TAGS =
        (
         all => [ @EXPORT_OK ],
        );
}
use parent qw( Exporter );

use WWW::EchoNest::Id qw( is_id );

use WWW::EchoNest::Config;
sub set_codegen_path {
    WWW::EchoNest::Config::set_codegen_binary_override( $_[0] );
}
sub set_api_key {
    WWW::EchoNest::Config::set_api_key( $_[0] );
}

use JSON;
sub pretty_json { to_json( $_[0], { utf8 => 1, pretty => 1 } ) }

use WWW::EchoNest::Logger;
sub set_log_level {
    WWW::EchoNest::Logger::set_log_level( $_[0] );
}


# Convenience Functions ######################################################

use WWW::EchoNest::Artist;
sub get_artist {
    return WWW::EchoNest::Artist->new($_[0]) if ref($_[0]) eq 'HASH';
    # Assume the arg is a string
    return WWW::EchoNest::Artist->new( { id   => $_[0] } ) if is_id( $_[0] );
    return WWW::EchoNest::Artist->new( { name => $_[0] } );
}

use WWW::EchoNest::Catalog;
sub get_catalog {
    return WWW::EchoNest::Catalog->new($_[0]) if ref($_[0]) eq 'HASH';
    # Assume the arg is a string
    return WWW::EchoNest::Catalog->new( { name => $_[0] } );
}

use WWW::EchoNest::Playlist;
sub get_playlist {
    return WWW::EchoNest::Playlist->new($_[0]) if ref($_[0]) eq 'HASH';
    # Assume the arg is either a string or an array ref,
    # and that we're creating an 'artist' playlist
    return WWW::EchoNest::Playlist->new( { artist => $_[0] } );
}

use WWW::EchoNest::Song;
sub get_song {
    return WWW::EchoNest::Song->new( $_[0] ) if ref($_[0]) eq 'HASH';
    # Assume the arg is a string
    return WWW::EchoNest::Song->new( { id   => $_[0] } ) if is_id($_[0]);
    return WWW::EchoNest::Song->new( { name => $_[0] } );
}

use WWW::EchoNest::Track qw( track_from_file );
sub get_track {
    # Assume the arg is a filename
    return track_from_file( $_[0] );
}

1;

__END__

=head1 NAME

WWW::EchoNest 0.0.1 - Perl module for accessing the Echo Nest API.

=head1 SYNOPSIS

use WWW::EchoNest qw(:all);
# Imports:
# - get_artist
# - get_catalog
# - get_playlist
# - get_song
# - get_track
# - pretty_json
# - set_log_level
# - set_codegen_path
# - set_api_key
# Each of which can also be imported individually.

use WWW::EchoNest::Artist; # So we can call Artist methods
my $artist = get_artist('talking heads');
my $audio_docs_list = 

=head1 FUNCTIONS

=head2 object_list

  Get a list of the objects for which WWW::EchoNest provides convenience functions.

  ARGUMENTS:
    none

  RETURNS:
    A list of object names.

  EXAMPLE:
    use WWW::EchoNest;
    my @object_list = WWW::EchoNest::object_list;

=head2 get_artist

  Convenience function for creating Artist objects.

  ARGUMENTS:
    See the documentation for WWW::EchoNest::Artist.
    $ perldoc WWW::EchoNest::Artist

  RETURNS:
    A new instance of WWW::EchoNest::Artist.

  EXAMPLE:
    use WWW::EchoNest qw{ artist };
    my $artist = artist( q{The Residents} );
    # ...

=head2 get_catalog

  Convenience function for creating Catalog objects.

  ARGUMENTS:
    See the documentation for WWW::EchoNest::Catalog.
    $ perldoc WWW::EchoNest::Catalog

  RETURNS:
    A new instance of WWW::EchoNest::Catalog.

  EXAMPLE:
    use WWW::EchoNest qw{ catalog };
    my $catalog = catalog( { name => q(my_songs), type => q(songs) } );
    # ...

=head2 get_config

  Convenience function for creating Config objects.

  ARGUMENTS:
    See the documentation for WWW::EchoNest::Config.
    $ perldoc WWW::EchoNest::Config

  RETURNS:
    A new instance of WWW::EchoNest::Config.

  EXAMPLE:
    use WWW::EchoNest qw{ config };
    use WWW::EchoNest::Config qw{ set_api_key };
    my $config = config( { name => q(my_songs), type => q(songs) } );
    # ...

=head2 get_playlist

  Convenience function for creating Playlist objects.

  ARGUMENTS:
    See the documentation for WWW::EchoNest::Playlist.
    $ perldoc WWW::EchoNest::Playlist

  RETURNS:
    A new instance of WWW::EchoNest::Playlist.

  EXAMPLE:
    use WWW::EchoNest qw{ playlist };
    my $playlist = playlist( { name => q(my_songs), type => q(songs) } );
    # ...

=head2 get_song

  Convenience function for creating Song objects.

  ARGUMENTS:
    See the documentation for WWW::EchoNest::Song.
    $ perldoc WWW::EchoNest::Song

  RETURNS:
    A new instance of WWW::EchoNest::Song.

  EXAMPLE:
    use WWW::EchoNest qw{ song };
    my $catalog = catalog( { name => q(my_songs), type => q(songs) } );
    # ...

=head2 get_track

  Convenience function for creating Track objects.

  ARGUMENTS:
    See the documentation for WWW::EchoNest::Track.
    $ perldoc WWW::EchoNest::Track

  RETURNS:
    A new instance of WWW::EchoNest::Track.

  EXAMPLE:
    use WWW::EchoNest qw( get_track );
    my $catalog = catalog( { name => q(my_songs), type => q(songs) } );
    # ...

=head1 AUTHOR

Brian Sorahan, C<< <bsorahan@gmail.com> >>

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

perldoc WWW::EchoNest

Also, join the Google group: <http://groups.google.com/group/www-echonest>

=head1 ACKNOWLEDGEMENTS

Thanks to all the folks at The Echo Nest for providing access to their
powerful API.

=head1 LICENSE AND COPYRIGHT

Copyright 2011 Brian Sorahan.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.
