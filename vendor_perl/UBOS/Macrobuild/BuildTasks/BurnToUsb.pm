# 
# Burn an image to a USB stick.
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::BurnToUsb;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields;

use UBOS::Logging;

##
# Constructor
sub new {
    my $self = shift;
    my %args = @_;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    
    $self->SUPER::new( %args );

    $self->{delegate} = new UBOS::Macrobuild::BasicTasks::BurnToUsb(
        'usbdevice' => '${usbdevice}',
        'image'     => '${repodir}/${arch}/uncompressed-images/ubos_${channel}_${deviceclass}_LATEST.img',
    );

    return $self;
}

1;


