# 
# Config file for upstream sources obtained from git
#

use strict;
use warnings;

package UBOS::Macrobuild::GitUsConfig;

use base qw( UBOS::Macrobuild::AbstractUsConfig );
use fields qw( branch );

use UBOS::Logging;
use UBOS::Utils;

##
# Constructor
sub new {
    my $self            = shift;
    my $name            = shift;
    my $configJson      = shift;
    my $file            = shift;
    my $localSourcesDir = shift;
    my $packages        = shift;
    my $webapptests     = shift;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    $self->SUPER::new( $name, $configJson, $file, $localSourcesDir, $packages, $webapptests );

    $self->{branch} = $configJson->{branch};

    unless( defined( $self->{branch} )) {
        fatal( 'No branch field defined in usConfig', $file );
    }
    unless( $self->{branch} =~ m!^[a-z0-9]+$!i ) {
        fatal( 'Invalid branch field in usConfig', $file );
    }

    return $self;
}

##
# Get the type
sub type {
    my $self = shift;

    return 'git';
}

##
# Get the branch
sub branch {
    my $self = shift;

    return $self->{branch};
}

1;
