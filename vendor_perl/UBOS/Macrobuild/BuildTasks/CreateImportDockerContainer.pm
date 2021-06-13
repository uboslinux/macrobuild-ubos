#!/usr/bin/perl
#
# Creates a bootable docker container and imports it.
#
# Copyright (C) 2017 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::CreateImportDockerContainer;

use base qw( Macrobuild::CompositeTasks::Sequential );
use fields qw( arch channel installDepotRoot runDepotRoot repodir imageName deviceConfig );

use UBOS::Macrobuild::BasicTasks::CreateContainer;
use UBOS::Macrobuild::BasicTasks::DockerContainerImport;

##
# Constructor
sub new {
    my $self = shift;
    my @args = @_;

    unless( ref $self ) {
        $self = fields::new( $self );
    }

    $self->SUPER::new( @args );

    my $deviceclass = 'docker';
    $self->appendTask( UBOS::Macrobuild::BasicTasks::CreateContainer->new(
            'name'              => 'Create ${arch} ' . $deviceclass . ' bootable directory named ${imageName} for ${channel}',
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

    $self->appendTask( UBOS::Macrobuild::BasicTasks::DockerContainerImport->new(
            'dockerName' => 'ubos/${imageName}-${channel}' ));

    return $self;
}

1;

