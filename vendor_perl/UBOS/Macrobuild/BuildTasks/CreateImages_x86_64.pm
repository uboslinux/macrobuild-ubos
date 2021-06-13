#!/usr/bin/perl
#
# Creates all images for x86_64
#
# Copyright (C) 2017 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::CreateImages_x86_64;

use base qw( Macrobuild::CompositeTasks::SplitJoin );
use fields qw( arch channel installDepotRoot runDepotRoot repodir );

use Macrobuild::BasicTasks::MergeValues;
use Macrobuild::CompositeTasks::Sequential;
use Macrobuild::Task;
use UBOS::Macrobuild::BasicTasks::CreateContainer;
use UBOS::Macrobuild::BasicTasks::CreateImage;
use UBOS::Macrobuild::BasicTasks::ImagesToVmdk;

##
# Constructor
sub new {
    my $self = shift;
    my @args = @_;

    unless( ref $self ) {
        $self = fields::new( $self );
    }

    $self->SUPER::new( @args );

    # pc

    my $deviceclass = 'pc';
    $self->addParallelTask(
            $deviceclass,
            UBOS::Macrobuild::BasicTasks::CreateImage->new(
                    'name'             => 'Create ${arch} ' . $deviceclass . ' disk image for ${channel}',
                    'arch'             => '${arch}',
                    'installDepotRoot' => '${installDepotRoot}',
                    'runDepotRoot'     => '${runDepotRoot}',
                    'channel'          => '${channel}',
                    'deviceclass'      => $deviceclass,
                    'imagesize'        => '7G',
                    'image'            => '${repodir}/${channel}/${arch}/uncompressed-images/ubos_${channel}_${arch}-' . $deviceclass . '_${tstamp}.img',
                    'linkLatest'       => '${repodir}/${channel}/${arch}/uncompressed-images/ubos_${channel}_${arch}-' . $deviceclass . '_LATEST.img' ));

    # vbox

    $deviceclass = 'vbox';
    my $vboxTask = Macrobuild::CompositeTasks::Sequential->new();

    $vboxTask->appendTask( UBOS::Macrobuild::BasicTasks::CreateImage->new(
            'name'             => 'Create ${arch} ' . $deviceclass . ' disk image for ${channel}',
            'arch'             => '${arch}',
            'installDepotRoot' => '${installDepotRoot}',
            'runDepotRoot'     => '${runDepotRoot}',
            'channel'          => '${channel}',
            'deviceclass'      => $deviceclass,
            'imagesize'        => '7G',
            'image'            => '${repodir}/${channel}/${arch}/uncompressed-images/ubos_${channel}_${arch}-' . $deviceclass . '_${tstamp}.img',
            'linkLatest'       => '${repodir}/${channel}/${arch}/uncompressed-images/ubos_${channel}_${arch}-' . $deviceclass . '_LATEST.img' ));

    $vboxTask->appendTask( UBOS::Macrobuild::BasicTasks::ImagesToVmdk->new());

    $self->addParallelTask(
            $deviceclass,
            $vboxTask );

    $self->setJoinTask( Macrobuild::BasicTasks::MergeValues->new(
            'name' => 'Merge images list for ${channel}',
            'keys' => [ 'pc', 'vbox' ] ));

    return $self;
}

1;
