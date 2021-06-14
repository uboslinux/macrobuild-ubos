#!/usr/bin/perl
#
# Uploads UBOS Docker images on a channel to Docker
#
# Copyright (C) 2015 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::UploadDockerContainerImages;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields qw( arch channel repodir imageName );

use Macrobuild::Task;
use UBOS::Macrobuild::BasicTasks::UploadDockerImages;

##
# Constructor
sub new {
    my $self = shift;
    my @args = @_;

    unless( ref $self ) {
        $self = fields::new( $self );
    }

    $self->SUPER::new( @args );

    $self->setDelegate( UBOS::Macrobuild::BasicTasks::UploadDockerImages->new(
            'name'       => 'Upload docker images ${imageName}-${channel}',
            'dockerName' => 'ubos/${imageName}-${channel}' ));

    return $self;
}

1;
