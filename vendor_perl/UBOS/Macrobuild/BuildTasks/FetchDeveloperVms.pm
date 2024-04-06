#!/usr/bin/perl
#
# Fetch
#
# Copyright (C) 2015 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::FetchDeveloperVms;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields qw( arch channel sourceLocation repodir exts );

use UBOS::Logging;
use UBOS::Macrobuild::BasicTasks::FetchFilesOverRsyncSsh;

##
# Constructor
sub new {
    my $self = shift;
    my @args = @_;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    $self->SUPER::new( @args );

    $self->setDelegate( UBOS::Macrobuild::BasicTasks::FetchFilesOverRsyncSsh->new(
            'name'           => 'Fetch developer VMs from ${sourceLocation}',
            'sourceLocation' => '${sourceLocation}',
            'destinationDir' => '${repodir}/${channel}/${arch}/images/',
            'exts'           => '${exts}'
    ));

    return $self;
}

1;


