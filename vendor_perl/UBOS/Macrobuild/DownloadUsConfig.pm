# 
# Config file for upstream sources obtained by download
#

use strict;
use warnings;

package UBOS::Macrobuild::DownloadUsConfig;

use base qw( UBOS::Macrobuild::AbstractUsConfig );
use fields;

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

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    $self->SUPER::new( $name, $configJson, $file, $localSourcesDir );

    return $self;
}

##
# Get the type
sub type {
	my $self = shift;
	
	return 'download';
}

1;
