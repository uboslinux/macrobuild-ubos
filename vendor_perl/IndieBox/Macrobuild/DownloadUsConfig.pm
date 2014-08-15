# 
# Config file for upstream sources obtained by download
#

use strict;
use warnings;

package IndieBox::Macrobuild::DownloadUsConfig;

use base qw( IndieBox::Macrobuild::AbstractUsConfig );
use fields;

use IndieBox::Utils;
use Macrobuild::Logging;

##
# Constructor
sub new {
    my $self        = shift;
    my $name        = shift;
    my $configJson  = shift;
    my $file        = shift;
    
    unless( ref $self ) {
        $self = fields::new( $self );
    }
    $self->SUPER::new( $name, $configJson, $file );

    return $self;
}

##
# Get the type
sub type {
	my $self = shift;
	
	return 'download';
}

1;
