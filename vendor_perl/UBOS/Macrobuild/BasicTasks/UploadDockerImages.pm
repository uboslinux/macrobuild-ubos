#!/usr/bin/perl
#
# Upload the Docker images on a channel that exist in the local Docker registry.
#
# Copyright (C) 2015 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::UploadDockerImages;

use base qw( Macrobuild::Task );
use fields qw( dockerName );

use File::Basename;
use Macrobuild::Task;
use UBOS::Logging;

##
# @Overridden
sub runImpl {
    my $self = shift;
    my $run  = shift;

    my $errors          = 0;
    my @pushedDockerIds = ();

    my $dockerName = $self->getPropertyOrDefault( 'dockerName', undef );
    if( $dockerName ) {
        if( UBOS::Utils::myexec( "sudo docker push --all-tags '$dockerName'" )) {
            error( 'Docker push failed of', $dockerName );
            ++$errors;
        }

    } else {
        error( 'No dockerName provided' );
        ++$errors;
    }

    if( $errors ) {
        return FAIL;
    } elsif( @pushedDockerIds ) {
        return SUCCESS;
    } else {
        return DONE_NOTHING;
    }
}

1;

