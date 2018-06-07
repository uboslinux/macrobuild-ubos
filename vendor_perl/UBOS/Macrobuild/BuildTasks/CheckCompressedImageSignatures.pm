#!/usr/bin/perl
#
# Check that all compressed images in a channel have
# corresponding signature files.
#
# Copyright (C) 2016 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::CheckCompressedImageSignatures;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields qw( arch channel repodir );

use Macrobuild::Task;
use UBOS::Macrobuild::BasicTasks::CheckSignatures;

##
# Constructor
sub new {
    my $self = shift;
    my @args = @_;

    unless( ref $self ) {
        $self = fields::new( $self );
    }

    $self->SUPER::new( @args );

    $self->setDelegate( UBOS::Macrobuild::BasicTasks::CheckSignatures->new(
            'name'  => 'Check signatures for compressed images on ${channel}',
            'dir'   => '${repodir}/${channel}/${arch}/images',
            'glob'  => '*.xz' ));

    return $self;
}

1;
