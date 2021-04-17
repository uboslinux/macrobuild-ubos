#!/usr/bin/perl
#
# Creates all images for ARM v7h
#
# Copyright (C) 2017 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::CreateImages_armv7h;

use base qw( Macrobuild::CompositeTasks::SplitJoin );
use fields qw( arch channel installDepotRoot runDepotRoot repodir );

use Macrobuild::BasicTasks::MergeValues;
use Macrobuild::CompositeTasks::Sequential;
use Macrobuild::Task;
use UBOS::Macrobuild::BasicTasks::CreateContainer;
use UBOS::Macrobuild::BasicTasks::CreateImage;

##
# Constructor
sub new {
    my $self = shift;
    my @args = @_;

    unless( ref $self ) {
        $self = fields::new( $self );
    }

    my @deviceclasses = qw( rpi2 rpi4 odroid-xu3 );

    $self->SUPER::new( @args );

    foreach my $deviceclass ( @deviceclasses ) {
        $self->addParallelTask(
                $deviceclass,
                UBOS::Macrobuild::BasicTasks::CreateImage->new(
                        'name'             => 'Create ${arch} ' . $deviceclass . ' boot disk image for ${channel}',
                        'arch'             => '${arch}',
                        'installDepotRoot' => '${installDepotRoot}',
                        'runDepotRoot'     => '${runDepotRoot}',
                        'channel'          => '${channel}',
                        'deviceclass'      => $deviceclass,
                        'imagesize'        => '7G',
                        'image'            => '${repodir}/${channel}/${arch}/uncompressed-images/ubos_${channel}_${arch}-' . $deviceclass . '_${tstamp}.img',
                        'linkLatest'       => '${repodir}/${channel}/${arch}/uncompressed-images/ubos_${channel}_${arch}-' . $deviceclass . '_LATEST.img' ));
    }

    my $deviceclass = 'container';
    $self->addParallelTask(
            $deviceclass,
            UBOS::Macrobuild::BasicTasks::CreateContainer->new(
                    'name'              => 'Create ${arch} bootable container for ${channel}',
                    'arch'              => '${arch}',
                    'installDepotRoot'  => '${installDepotRoot}',
                    'runDepotRoot'      => '${runDepotRoot}',
                    'channel'           => '${channel}',
                    'deviceclass'       => $deviceclass,
                    'dir'               => '${repodir}/${channel}/${arch}/uncompressed-images/ubos_${channel}_${arch}-' . $deviceclass . '_${tstamp}.tardir',
                    'linkLatest-dir'    => '${repodir}/${channel}/${arch}/uncompressed-images/ubos_${channel}_${arch}-' . $deviceclass . '_LATEST.tardir',
                    'tarfile'           => '${repodir}/${channel}/${arch}/uncompressed-images/ubos_${channel}_${arch}-' . $deviceclass . '_${tstamp}.tar',
                    'linkLatest-tarfile'=> '${repodir}/${channel}/${arch}/uncompressed-images/ubos_${channel}_${arch}-' . $deviceclass . '_LATEST.tar' ));

    $self->setJoinTask( Macrobuild::BasicTasks::MergeValues->new(
            'name' => 'Merge images list for ${channel}',
            'keys' => [ @deviceclasses, 'container' ] ));

    return $self;

}

1;
