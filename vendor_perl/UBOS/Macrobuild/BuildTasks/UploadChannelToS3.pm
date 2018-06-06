#!/usr/bin/perl
#
# Uploads a locally staged channel to Amazon S3
#
# Copyright (C) 2014 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Macrobuild::BuildTasks::UploadChannelToS3;

use base qw( Macrobuild::CompositeTasks::Delegating );
use fields qw( arch channel repodir uploadDest uploadInExclude );

use Macrobuild::Task;
use UBOS::Macrobuild::BasicTasks::UploadToS3;

##
# Constructor
sub new {
    my $self = shift;
    my @args = @_;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    $self->SUPER::new( @args );

    $self->setDelegate( UBOS::Macrobuild::BasicTasks::UploadToS3->new(
            'from'      => '${repodir}/${channel}/${arch}',
            'to'        => '${uploadDest}/${arch}',
            'inexclude' => '${uploadInExclude}' ));

    return $self;
}

1;
