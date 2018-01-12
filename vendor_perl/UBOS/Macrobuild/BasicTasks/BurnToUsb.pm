#!/usr/bin/perl
#
# Burn an image to a USB stick.
#
# Copyright (C) 2015 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::BurnToUsb;

use base   qw( Macrobuild::Task );
use fields qw( usbdevice image );

use Macrobuild::Task;
use UBOS::Logging;

##
# @Overridden
sub runImpl {
    my $self = shift;
    my $run  = shift;

    my $in = $run->getInput();

    my $ret;
    my $usbDevice = $self->getProperty( 'usbdevice' );
    my $image     = $self->getProperty( 'image' );

    if( $usbDevice && $image && -f $image ) {
        if( -b $usbDevice ) {
            my $out;
            if( UBOS::Utils::myexec( 'mount', undef, \$out )) {
                error( 'mount failed' );
                $ret = FAIL;
            } elsif( $out =~ $usbDevice ) {
                error( 'USB device', $usbDevice, 'is mounted and cannot be used to burn to' );
                $ret = FAIL;
            } elsif( UBOS::Utils::myexec( "sudo dd 'if=$image' 'of=$usbDevice' bs=1M status=none" )) {
                error( 'Writing image', $image, 'to USB device', $usbDevice, 'failed' );
                $ret = FAIL;
            } else {
                UBOS::Utils::myexec( "sync" );
                $ret = SUCCESS;
            }

        } else {
            error( 'Not a USB device:', $usbDevice );
            $ret = FAIL;
        }

    } elsif( !$usbDevice ) {
        warning( 'No usbdevice given, skipping burn' );
        $ret = FAIL;
    } elsif( $image ) {
        error( 'Image not readable', $image );
        $ret = FAIL;
    } else {
        error( 'No image given' );
        $ret = FAIL;
    }

    return $ret;
}

1;
