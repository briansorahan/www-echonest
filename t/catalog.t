#!/usr/bin/perl -T

use 5.010;
use strict;
use warnings;

use Test::More 'no_plan';

BEGIN {
    use_ok( 'WWW::EchoNest',             qw[ get_catalog get_artist        ] );
    use_ok( 'WWW::EchoNest::Id',         qw[ is_id                         ] );
    use_ok( 'WWW::EchoNest::Catalog',    qw[ list_catalogs _types          ] );
    use_ok( 'WWW::EchoNest::Song',       qw[ search_song                   ] );
    use_ok( 'WWW::EchoNest::Artist'                                          );
}

my @catalog_types = WWW::EchoNest::Catalog::_types;
my @catalogs = ();

########################################################################
#
# Catalog creation
#
my $song_catalog
    = new_ok(
             'WWW::EchoNest::Catalog',
             [ { name => 'my_songs', type => 'song' } ]
            );

my $artist_catalog
    = new_ok(
             'WWW::EchoNest::Catalog',
             [ { name => 'my_artists', type => 'artist' } ]
            );

my $easy_catalog = get_catalog('some_songs');
push @catalogs, ($song_catalog, $artist_catalog, $easy_catalog);

########################################################################
#
# get_id
#
for my $catalog (@catalogs) {
    my $catalog_id = $catalog->get_id;
    ok( defined($catalog_id), 'get_id returns a defined result' );
    ok( is_id($catalog_id), 'get_id returns a valid identifier' );
}


########################################################################
#
# get_type
#
use List::Util qw( first );
for my $catalog (@catalogs) {
    my $catalog_type = $catalog->get_type();
    ok( first { $_ eq $catalog_type } @catalog_types, 'get_type checks out' );
}


########################################################################
#
# add_song
#
my $heaven_song_ref
    = search_song( { artist => 'Talking Heads', title => 'Heaven' } );
can_ok( $song_catalog, qw[ add_song ] );
isa_ok( $heaven_song_ref, 'WWW::EchoNest::Song' );
my $song_ticket = $song_catalog->add_song( $heaven_song_ref );



########################################################################
#
# add_artist
#
my $artist_ref = get_artist('Autechre');
can_ok( $artist_catalog, qw[ add_artist ] );
isa_ok( $artist_ref, 'WWW::EchoNest::Artist' );
my $artist_ticket = $artist_catalog->add_artist( $artist_ref );



########################################################################
#
# status
#
can_ok( $artist_catalog, qw[ status ] );
my $artist_ticket_status = $artist_catalog->status($artist_ticket);
ok( defined($artist_ticket_status), 'status returns a defined result' );
is( ref($artist_ticket_status), 'HASH', 'status returns a HASH ref' );



########################################################################
#
# get_profile
#
can_ok( $song_catalog, qw/ get_profile / );
my $song_catalog_profile = $song_catalog->get_profile();
ok( defined($song_catalog_profile), 'get_profile returns a defined result' );
is( ref($song_catalog_profile), 'HASH', 'get_profile returns a HASH ref' );



########################################################################
#
# read_items
#
can_ok( $artist_catalog, qw[ read_items ] );
my $artist_catalog_objects = $artist_catalog->read_items( { results => 2 } );
ok( defined($artist_catalog_objects), 'read_items returns a defined result' );
isa_ok(
       $artist_catalog_objects,
       'WWW::EchoNest::Result::List',
       'read_items returns an instance of WWW::EchoNest::ResultList'
      );
ok( defined($artist_catalog_objects->get(0)), 'read_items()->get(0) is defined' );
isa_ok(
       $artist_catalog_objects->get(0),
       'WWW::EchoNest::Artist',
       'read_items()->get(0) returns an instance of WWW::EchoNest::Artist'
      );



########################################################################
#
# get_feed
#
can_ok( $artist_catalog, qw[ get_feed ] );
my $artist_catalog_feed = $artist_catalog->get_feed( { results => 10 } );
ok( defined($artist_catalog_feed), 'get_feed returns a defined result' );
isa_ok( $artist_catalog_feed, 'WWW::EchoNest::Result::List' ); # HASH refs...
is(
   ref( $artist_catalog_feed->get(0) ),
   'HASH',
   'feed returns a list of HASH refs'
  );



########################################################################
#
# list_catalogs
#
can_ok( 'WWW::EchoNest::Catalog', qw/ list_catalogs / );
my @catalog_list = list_catalogs( { results => 10 } );
ok( @catalog_list, 'list_catalogs returns a non-empty array' );
isa_ok( $_, 'WWW::EchoNest::Catalog' ) for (@catalog_list);



########################################################################
#
# delete
# - Returns the id of the deleted catalog.
#
for my $catalog (@catalogs) {
    can_ok( $catalog, qw[ delete ] );
    my $catalog_deleted = $catalog->delete();
    ok( defined($catalog_deleted), 'delete returns a defined result' );
    is( ref($catalog_deleted), 'HASH', 'delete returns a HASH ref' );
    ok( exists $catalog_deleted->{id},
        'delete returns a HASH ref with an id field' );
    ok( is_id( $catalog_deleted->{id} ),
        'delete returns a HASH whose value for the \'id\' entry is a valid id' );
}
