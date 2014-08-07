# 
# Config file for upstream sources obtained from git
#

use strict;
use warnings;

package IndieBox::Macrobuild::GitUsConfig;

use base qw( IndieBox::Macrobuild::AbstractUsConfig );
use fields qw( branch );

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
    $self->SUPER::new( $name, $configJson );

    $self->{branch} = $configJson->{branch};

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
