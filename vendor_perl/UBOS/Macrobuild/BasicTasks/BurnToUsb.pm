# 
# Burn an image to a USB stick.
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::BurnToUsb;

use base   qw( Macrobuild::Task );
use fields qw( usbdevice image );

use UBOS::Logging;

##
# Run this task.
# $run: the inputs, outputs, settings and possible other context info for the run
sub run {
    my $self = shift;
    my $run  = shift;

    my $in = $run->taskStarting( $self );
    
    my $ret;
    my $usbDevice = $self->{usbdevice};
    my $image     = $self->{image};

    if( $usbDevice && $image && -f $image ) {
        if( -b $usbDevice ) {
            my $out;
            if( UBOS::Utils::myexec( 'mount', undef, \$out )) {
                error( 'mount failed' );
                $ret = 1;
            } elsif( $out =~ $usbDevice ) {
                error( 'USB device', $usbDevice, 'is mounted and cannot be used to burn to' );
                $ret = 1;
            } elsif( UBOS::Utils::myexec( "sudo dd 'if=$image' 'of=$usbDevice' bs=1M" ) {
                error( 'Writing image', $image, 'to USB device', $usbDevice, 'failed' );
                $ret = 1;
            } else {
                $ret = 0;
            }
            
        } else {
            error( 'Not a USB device:', $usbDevice );
            $ret = -1;
        }
        
    } elsif( !$usbDevice ) {
        warning( 'No usbdevice given, skipping burn' );
        $ret = 1;
    } else {
        warning( 'No image given, or image not readable' );
        $ret = 1;
    }
    
    $run->taskEnded(
            $self,
            {},
            $ret );

    return $ret;
}

1;