#!/usr/bin/perl -T

use 5.010;
use strict;
use warnings;

use Test::More 'no_plan';

BEGIN {
    use_ok( 'WWW::EchoNest', qw( :all  ) );
    use_ok( 'WWW::EchoNest::ConfigData' );
}



# For testing get_track #################################################
#
my $test_file = WWW::EchoNest::ConfigData->feature( 'test_file' );



# Test the entire API ###################################################
#
my @funcs = qw( get_artist get_catalog get_playlist get_song get_track is_id );
can_ok( 'WWW::EchoNest', @funcs );



# get_artist ############################################################
#
my $autechre = get_artist('autechre');
ok( defined($autechre), 'get_artist returns a defined result' );
isa_ok( $autechre, 'WWW::EchoNest::Artist' );



# get_catalog ############################################################
#
my $artist_catalog = get_catalog('my_artists');
ok( defined($artist_catalog), 'get_catalog returns a defined result' );
isa_ok( $artist_catalog, 'WWW::EchoNest::Catalog' );



# get_playlist ############################################################
#
# - Defaults to an 'artist' type, so the only required parameter (if
#   you're just looking to create an artist-based playlist) is an artist
#   name.
#
my $afx_playlist = get_playlist('aphex twin');
ok( defined($afx_playlist), 'get_playlist returns a defined result' );
isa_ok( $afx_playlist, 'WWW::EchoNest::Playlist' );



# get_song ################################################################
#
my $skinny_song = get_song('SOWWTEP12A8C13F50E');
ok( defined($skinny_song), 'get_song returns a defined result' );
isa_ok( $skinny_song, 'WWW::EchoNest::Song' );



# get_track ###############################################################
#
my $wjoojoo_track = get_track($test_file);
ok( defined($wjoojoo_track), 'get_track returns a defined result' );
isa_ok( $wjoojoo_track, 'WWW::EchoNest::Track' );

