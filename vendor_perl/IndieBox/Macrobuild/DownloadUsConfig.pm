# 
# Config file for upstream sources obtained by download
#

use strict;
use warnings;

package IndieBox::Macrobuild::DownloadUsConfig;

use fields qw( name url directories );

use IndieBox::Utils;
use Macrobuild::Logging;

##
# Constructor
sub new {
    my $self        = shift;
    my $name        = shift;
    my $url         = shift;
    my $directories = shift;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    $self->{name}        = $name;
    $self->{url}         = $url;
    $self->{directories} = $directories;

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
	
	return 'download';
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

1;
