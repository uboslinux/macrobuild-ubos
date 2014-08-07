# 
# Abstract supertype for various implementations of config files for upstream sources
#

use strict;
use warnings;

package IndieBox::Macrobuild::AbstractUsConfig;

use fields qw( name url directories webapptests );

use IndieBox::Utils;
use Macrobuild::Logging;

##
# Constructor
sub new {
    my $self        = shift;
    my $name        = shift;
    my $configJson  = shift;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    $self->{name}        = $name;
    $self->{url}         = $configJson->{url};
    $self->{directories} = $configJson->{directories};
    $self->{webapptests} = $configJson->{webapptests};

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
# Get the list of directories
sub directories {
    my $self = shift;

    return $self->{directories};
}

##
# Get a list of webapptests
sub webapptests {
    my $self = shift;
    
    return $self->{webapptests};
}

1;
