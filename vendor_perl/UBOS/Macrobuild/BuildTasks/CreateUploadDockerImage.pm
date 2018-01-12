#!/usr/bin/perl
#
# Creates and uploads an UBOS image to Docker
#
# Copyright (C) 2015 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::CreateUploadDockerImage;

use base qw( Macrobuild::CompositeTasks::Sequential );
use fields qw( arch channel repodir );

use Macrobuild::Task;
use UBOS::Macrobuild::BasicTasks::CreateDockerImage;
use UBOS::Macrobuild::BasicTasks::UploadDockerImage;

##
# Constructor
sub new {
    my $self = shift;
    my @args = @_;

    unless( ref $self ) {
        $self = fields::new( $self );
    }

    $self->SUPER::new( @args );

    $self->appendTask( UBOS::Macrobuild::BasicTasks::CreateDockerImage->new(
            'image'      => '${repodir}/${channel}/${arch}/uncompressed-images/ubos_${channel}_${arch}-container_LATEST.tar',
            'dockerName' => 'ubos/ubos-${channel}' ));

    $self->appendTask( UBOS::Macrobuild::BasicTasks::UploadDockerImage->new());

    return $self;
}

1;

