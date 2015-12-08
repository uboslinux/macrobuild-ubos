# 
# Burn an image to a USB stick.
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::BurnToUsb;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields;

use UBOS::Logging;
use UBOS::Macrobuild::BasicTasks::BurnToUsb;

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
        'name'      => 'Burning to ${usbdevice}',
        'usbdevice' => '${usbdevice}',
        'image'     => '${repodir}/${arch}/uncompressed-images/ubos_${channel}-${deviceclass}_LATEST.img',
    );

    return $self;
}

1;


