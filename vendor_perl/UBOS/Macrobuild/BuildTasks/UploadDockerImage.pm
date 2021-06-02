#!/usr/bin/perl
#
# Uploads an UBOS image to Docker
#
# Copyright (C) 2015 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::UploadDockerImage;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields qw( arch channel repodir );

use Macrobuild::Task;
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

    $self->setDelegate( UBOS::Macrobuild::BasicTasks::UploadDockerImage->new(
            'dockerName' => 'ubos/ubos-${channel}' ));

    return $self;
}

1;
