#!/usr/bin/perl
#
# Update a Git repository by pulling it
#
# Copyright (C) 2017 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::PullGit;

use base qw( Macrobuild::Task );
use fields qw( dir branch );

use Macrobuild::Task;
use UBOS::Logging;

##
# @Overridden
sub runImpl {
    my $self = shift;
    my $run  = shift;

    my $dir    = $self->getProperty( 'dir' );
    my $branch = $self->getProperty( 'branch' );

    my $gitCmd = "git checkout -- . ; git checkout '$branch' ; git pull";

    my $out;
    my $err;
    UBOS::Utils::myexec( "( cd '$dir'; $gitCmd )", undef, \$out, \$err );
    if( $err =~ m!^error!m ) {
        error( 'Error when attempting to pull git repository:', $dir, "\n$err" );
        return FAIL;
    }

    $run->setOutput( {
            'updatedDir' => $dir
    } );

    return SUCCESS;
}

1;

