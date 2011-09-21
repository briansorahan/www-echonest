
package WWW::EchoNest::Artist;

use 5.010;
use strict;
use warnings;
use Carp;
use List::Util qw( first );

use WWW::EchoNest::Functional qw(
                                    keep
                                    stupid_get_attr
                                    simple_get_attr
                                    editorial_get_attr
                                    numerical_get_attr
                               );

use WWW::EchoNest::Util qw(
                              fix_keys
                              call_api
                         );

use WWW::EchoNest::Result::List;

BEGIN {
    our @EXPORT      = qw(  );
    our @EXPORT_OK   =
        (
         'list_terms',
         'similar',
         'search_artist',
         'top_hottt',
         'top_terms',
        );
}
use parent qw( WWW::EchoNest::Proxy::Artist Exporter );

use overload
    '""' => '_stringify',
    ;



# # # # METHODS # # # #

sub new {
    my $class       = $_[0];
    my $args_ref    = $_[1];
    return $class->SUPER::new( $args_ref );
}



sub get_audio {
    return stupid_get_attr( $_[0], $_[1], 'audio' );
}

sub get_biographies {
    return simple_get_attr( $_[0], $_[1], 'biographies' );
}

sub get_blogs {
    return editorial_get_attr( $_[0], $_[1], 'blogs' );
}

sub get_familiarity {
    return numerical_get_attr( $_[0], $_[1], 'familiarity' );
}

# This one is unique!
sub get_foreign_id {
    my($self, $args_href) = @_;
    
    my $idspace      = $args_href->{idspace}       // 'musicbrainz';
    my $cache        = $args_href->{cache}         // 1;
    my $cached_val   = $self->{foreign_ids};
    my @matches      = grep { $_->{catalog} eq $idspace } @$cached_val;
    my $match        = $matches[0]->{foreign_id};

    # Possibly return the cached value
    return $match if $cache and $cached_val and $match;

    # Get a new value
    my $response = $self->get_attribute(
                                        {
                                         method => 'profile',
                                         bucket => "id:$idspace"
                                        }
                                       );
    my $foreign_ids = $response->{artist}{foreign_ids}   // [];
    push @{ $self->{foreign_ids} }, @$foreign_ids;
    @matches = grep { $_->{catalog} eq $idspace } @{ $self->{foreign_ids} };
    return $matches[0]->{foreign_id};
}

sub get_hotttnesss {
    return numerical_get_attr( $_[0], $_[1], 'hotttnesss' );
}

sub get_images {
    return simple_get_attr( $_[0], $_[1], 'images' );
}

sub get_news {
    return editorial_get_attr( $_[0], $_[1], 'news' );
}

sub get_reviews {
    return stupid_get_attr( $_[0], $_[1], 'reviews' );
}

sub get_similar {
    my($self, $args_href) = @_;
    my $cache             = $args_href->{cache}       // 1;
    my $start             = $args_href->{start}       // 0;
    my $results           = $args_href->{results}     // 15;
    my $limit             = $args_href->{limit}       // 0;
    my $reverse           = $args_href->{reverse}     // 0;
    my $buckets           = $args_href->{buckets}     || [];
    my $cached_val        = $self->{similar};

    my $kwargs_href = keep( $args_href, sub { $_[0] },
                             [ qw( min_familiarity max_familiarity
                                   min_hotttnesss  max_hotttnesss
                                   min_results buckets limit reverse
                                ) ] );

    $kwargs_href->{bucket} = delete $kwargs_href->{buckets}
        if $kwargs_href->{buckets};

    $kwargs_href->{limit}   = 'true' if $kwargs_href->{limit};
    $kwargs_href->{reverse} = 'true' if $kwargs_href->{reverse};
    
    my @artist_list
        = map { WWW::EchoNest::Artist->new(fix_keys($_)) } @$cached_val;
    
    return \@artist_list if $cache and $cached_val and $results == 15
        and $start == 0 and not $kwargs_href;

    my $request_href = {};
    for (keys %$kwargs_href) {
        $request_href->{$_} = $kwargs_href->{$_} if exists $kwargs_href->{$_};
    }
    $request_href->{method}    = 'similar';
    $request_href->{start}     = $start;
    $request_href->{results}   = $results;
    
    my $response = $self->get_attribute( $request_href );
    $self->{similar} = $response->{artists}
        if $results == 15 and $start == 0 and not $kwargs_href;

    my @artists = map { WWW::EchoNest::Artist->new(fix_keys($_)) }
        @{ $response->{artists} };
    return \@artists;
}

sub get_songs {
    my($self, $args_href) = @_;

    my $cache      = $args_href->{cache}     // 1;
    my $start      = $args_href->{start}     // 0;
    my $results    = $args_href->{results}   // 15;
    my $cached_val = $self->{songs};

    # Possibly return the cached value
    return $cached_val
        if $cache and $cached_val and $start == 0 and $results == 15;

    # Get a new value for the attribute
    my $response = $self->get_attribute( {
                                          method    => 'songs',
                                          start     => $start,
                                          results   => $results,
                                         } );
    my @song_list = @{ $response->{songs} };
    for (@song_list) {
        $_->{artist_name} = $self->get_name();
        $_->{artist_id}   = $self->get_id();
    }
    my @songs = map { WWW::EchoNest::Song->new(fix_keys($_)) } @song_list;
    my $result_list = WWW::EchoNest::Result::List->new
        ( \@songs, start => 0, total => $response->{total} );

    # Cache the new value and return it
    $self->{songs} = $result_list;
    return $result_list;
}

sub get_terms {
    my($self, $args_href) = @_;
    my $cache       = $args_href->{cache}  // 1;
    my $sort        = $args_href->{sort}   // 'weight';
    my $cached_val  = $self->{terms};
    
    return $cached_val if $cache and $cached_val and $sort eq 'weight';
    my $response   = $self->get_attribute( { method => 'terms', sort => $sort } );
    my $new_value  = $response->{terms};
    $self->{terms} = $new_value if $sort eq 'weight';
    return $new_value;
}

sub get_urls {
    my($self, $args_href) = @_;
    my $cache      = $args_href->{cache} // 1;
    my $cached_val = $self->{urls};
    return $cached_val if $cache and $cached_val;
    my $response = $self->get_attribute( { method => 'urls' } );
    return $self->{urls} = $response->{urls};
}

sub get_video {
    return stupid_get_attr( $_[0], $_[1], 'video' );
}



########################################################################
#
# FUNCTIONS
#
sub _stringify {
    return q[<Artist - '] . $_[0]->get_name . q['>];
}

sub list_terms {
    my $result_href = call_api(
                               {
                                method => 'artist/list_terms',
                                params => { type => $_[0] // 'style' },
                               }
                              );
    return $result_href->{response}{terms};
}

sub similar {
    my %args                = %{ $_[0] };
    my $buckets             = $args{buckets}    // [];
    my $start               = $args{start}      // 0;
    my $results             = $args{results}    // 15;
    my $limit               = $args{limit}      // 0;

    $args{names} = [ $args{names} ] if ref($args{names}) ne 'ARRAY';
    $args{ids}   = [ $args{ids} ]   if ref($args{ids})   ne 'ARRAY';

    my $keep_if_defined = sub {
        my $keepers =
            [
             'max_familiarity',
             'min_familiarity',
             'max_hotttnesss',
             'min_hotttnesss',
             'seed_catalog',
            ];
        return keep( $_[0], sub { defined($_[0]) }, $keepers );
    };

    my $keep_if_true = sub {
        my $keepers = [ qw[ names ids results buckets start limit ] ];
        return keep( $_[0], sub { $_[0] }, $keepers );
    };
    my $request_href = $keep_if_defined->( $keep_if_true->( \%args ) );

    $request_href->{limit} = 'true' if $request_href->{limit};

    $request_href->{name}  = delete $request_href->{names}
        if $request_href->{names};

    $request_href->{id}  = delete $request_href->{ids}
        if $request_href->{ids};

    my $result_href = call_api(
                               {
                                method => 'artist/similar',
                                params => $request_href,
                               }
                              );

    my @artist_list = map { WWW::EchoNest::Artist->new(fix_keys($_)) }
        @{ $result_href->{response}{artists} };

    return \@artist_list;
}

sub search_artist {
    my %args               = %{ $_[0] };

    # Set defaults
    my $buckets            = $args{buckets}              // [];
    my $start              = $args{start}                // 0;
    my $results            = $args{results}              // 15;
    my $limit              = $args{limit}                // 0;
    my $fuzzy_match        = $args{fuzzy_match}          // 0;

    my $keep_if_defined = sub {
        my $keepers = [ qw( max_familiarity min_familiarity
                            max_hotttnesss  min_hotttnesss
                            test_new_things ) ];
        return keep( $_[0], sub { defined($_[0]) }, $keepers );
    };
    my $keep_if_true = sub {
        my $keepers = [ qw( name description style mood results start buckets
                            limit fuzzy_match sort rank_type ) ];
        return keep( $_[0], sub { $_[0] }, $keepers );
    };
    my $request_href = $keep_if_defined->( $keep_if_true->( \%args ) );
    
    $request_href->{limit}       = 'true' if $request_href->{limit};
    $request_href->{fuzzy_match} = 'true' if $request_href->{fuzzy_match};

    my $result_href = call_api(
                               {
                                method => 'artist/search',
                                params => $request_href,
                               }
                              );
    my @artist_list = map { WWW::EchoNest::Artist->new(fix_keys($_)) }
        @{ $result_href->{response}{artists} };
    return \@artist_list;
}

sub top_hottt {
    my %args          = %{ $_[0] };
    
    # Set defaults
    $args{buckets}  //= [];
    $args{limit}    //= 0;
    $args{start}    //= 0;
    $args{results}  //= 15;

    # Filter the args
    my $request_href = keep( \%args, sub { wantarray ? @_ : $_[0] },
                           [ qw( start results buckets limit ) ] );
    
    $request_href->{limit}  = 'true' if $request_href->{limit};
    $request_href->{bucket} = delete $request_href->{buckets}
        if $request_href->{buckets};
    
    my $result_href = call_api(
                               {
                                method => 'artist/top_hottt',
                                params => $request_href,
                               }
                              );
    my @artist_list = map {  WWW::EchoNest::Artist->new( fix_keys($_) )  }
        @{ $result_href->{'response'}{'artists'} };
    return \@artist_list;
}

sub top_terms {
    my($args_ref) = $_[0];
    my %request_args = ();
    $request_args{results}  = $args_ref->{results} if $args_ref->{results};
    my $result_hash_ref
        = call_api(
                   {
                    method     => 'artist/top_terms',
                    params     => \%request_args,
                   }
                  );
    
    return $result_hash_ref->{response}{terms};
}

1;
