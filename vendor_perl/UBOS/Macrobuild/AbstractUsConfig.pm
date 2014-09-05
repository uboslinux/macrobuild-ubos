# 
# Abstract supertype for various implementations of config files for upstream sources
#

use strict;
use warnings;

package UBOS::Macrobuild::AbstractUsConfig;

use fields qw( name url file packages webapptests );

use UBOS::Logging;
use UBOS::Utils;

##
# Constructor
sub new {
    my $self       = shift;
    my $name       = shift;
    my $configJson = shift;
    my $file       = shift;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    $self->{name}        = $name;
    $self->{url}         = $configJson->{url};
    $self->{file}        = $configJson->{file};
    $self->{packages}    = $configJson->{packages};
    $self->{webapptests} = $configJson->{webapptests};

    unless( defined( $name )) {
        fatal( 'No name provided for usConfig', $file );
    }
    unless( $name =~ m!^[-_a-z]+$! ) {
        fatal( 'Invalid name for usConfig', $file );
    }
    unless( defined( $self->{url} )) {
        fatal( 'No url field defined in usConfig', $file );
    }
    unless( $self->{url} =~ m!^[a-z]+://.*$! ) {
        fatal( 'Invalid url field in usConfig', $file );
    }

    unless( defined( $self->{packages} )) {
        fatal( 'No packages field defined in usConfig', $file );
    }
    unless( ref( $self->{packages} ) eq 'HASH' ) {
        fatal( 'Packages field must be hash in usConfig', $file );
    }

    return $self;
}

##
# Get the name
sub name {
    my $self = shift;

    return $self->{name};
}

##
# Get the type
sub type {
	my $self = shift;
	
    fatal( 'Must override', ref( $self ));
}

##
# Get the url
sub url {
    my $self = shift;

    return $self->{url};
}

##
# Get the list of packages
sub packages {
    my $self = shift;

    return $self->{packages};
}

##
# Get a list of webapptests
sub webapptests {
    my $self = shift;
    
    return $self->{webapptests};
}

1;
