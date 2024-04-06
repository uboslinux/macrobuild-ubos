#!/usr/bin/perl
#
# Fetch files over the network using rsync and ssh
#
# Copyright (C) 2015 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::FetchFilesOverRsyncSsh;

use base   qw( Macrobuild::Task );
use fields qw( sourceLocation destinationDir exts );

use Macrobuild::Task;
use UBOS::Logging;

##
# @Overridden
sub runImpl {
    my $self = shift;
    my $run  = shift;

    my $in = $run->getInput();

    my $ret = SUCCESS;

    my $sourceLocation = $self->getProperty( 'sourceLocation' );
    my $destinationDir = $self->getProperty( 'destinationDir' );
    my $exts           = $self->getProperty( 'exts' );

    foreach my $ext ( split / /, $exts ) {
        # rsync does not understand *{.a,.b}

        my $cmd = 'rsync -e ssh';
        $cmd .= ' --progress';
        $cmd .= " '$sourceLocation";
        unless( $sourceLocation =~ m!/$! ) {
            $cmd .= '/';
        }
        $cmd .= '*';
        $cmd .= $ext;
        $cmd .= "' '$destinationDir'";

        if( UBOS::Utils::myexec( $cmd )) {
            error( 'rsync failed, cmd was', $cmd );
            $ret = FAIL;
            last;
        }
    }

    return $ret;
}

1;
