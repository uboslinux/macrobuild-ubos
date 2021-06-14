#!/usr/bin/perl
#
# Creates a systemd-nspawn container image. This is the same for all archs.
#
# Copyright (C) 2017 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::CreateContainerImage;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields qw( arch channel installDepotRoot runDepotRoot repodir imageName deviceConfig );

use UBOS::Macrobuild::BasicTasks::CreateContainer;

##
# Constructor
sub new {
    my $self = shift;
    my @args = @_;

    unless( ref $self ) {
        $self = fields::new( $self );
    }

    $self->SUPER::new( @args );

    my $deviceclass = 'container';
    $self->setDelegate(
            UBOS::Macrobuild::BasicTasks::CreateContainer->new(
                    'name'              => 'Create ${arch} bootable container ${imageName} for ${channel}',
                    'arch'              => '${arch}',
                    'installDepotRoot'  => '${installDepotRoot}',
                    'runDepotRoot'      => '${runDepotRoot}',
                    'channel'           => '${channel}',
                    'deviceclass'       => $deviceclass,
                    'deviceConfig'      => '${deviceConfig}',
                    'dir'               => '${repodir}/${channel}/${arch}/uncompressed-images/${imageName}_${channel}_${arch}-' . $deviceclass . '_${tstamp}.tardir',
                    'linkLatest-dir'    => '${repodir}/${channel}/${arch}/uncompressed-images/${imageName}_${channel}_${arch}-' . $deviceclass . '_LATEST.tardir',
                    'tarfile'           => '${repodir}/${channel}/${arch}/uncompressed-images/${imageName}_${channel}_${arch}-' . $deviceclass . '_${tstamp}.tar',
                    'linkLatest-tarfile'=> '${repodir}/${channel}/${arch}/uncompressed-images/${imageName}_${channel}_${arch}-' . $deviceclass . '_LATEST.tar' ));

    return $self;
}

1;

