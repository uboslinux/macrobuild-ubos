#!/usr/bin/perl
#
# Burn an image to a USB stick.
#
# Copyright (C) 2015 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::BurnToUsb;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields qw( arch channel deviceclass repodir usbdevice );

use UBOS::Logging;
use UBOS::Macrobuild::BasicTasks::BurnToUsb;

##
# Constructor
sub new {
    my $self = shift;
    my @args = @_;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    $self->SUPER::new( @args );

    $self->setDelegate( UBOS::Macrobuild::BasicTasks::BurnToUsb->new(
            'name'      => 'Burning image for ${deviceclass} to ${usbdevice}',
            'usbdevice' => '${usbdevice}',
            'image'     => '${repodir}/${channel}/${arch}/uncompressed-images/ubos_${channel}_${arch}-${deviceclass}_LATEST.img'
    ));

    return $self;
}

1;


