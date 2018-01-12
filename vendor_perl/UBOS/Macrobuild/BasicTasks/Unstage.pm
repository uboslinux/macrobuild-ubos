#!/usr/bin/perl
#
# Unstage removed packages from the stage directory
#
# Copyright (C) 2016 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::Unstage;

use base qw( Macrobuild::Task );
use fields qw( stagedir arch );

use Macrobuild::Task;
use UBOS::Macrobuild::Utils;
use UBOS::Logging;
use UBOS::Utils;

##
# @Overridden
sub runImpl {
    my $self = shift;
    my $run  = shift;

    my $in = $run->getInput();

    my $unstaged     = {};
    my $removedFiles = [];

    if( exists( $in->{'removed-packages'} )) {

        my $removedPackages = $in->{'removed-packages'};

        my $stagedir = $self->getProperty( 'stagedir' );
        my $arch     = $self->getProperty( 'arch' );

        UBOS::Macrobuild::Utils::ensureDirectories( $stagedir );

        if( %$removedPackages ) {
            foreach my $uXConfigName ( sort keys %$removedPackages ) {
                my $uXConfigData = $removedPackages->{$uXConfigName};

                foreach my $packageName ( sort keys %$uXConfigData ) {

                    my @files = UBOS::Macrobuild::PackageUtils::packageVersionsInDirectory( $packageName, $stagedir, $arch );
                    if( @files ) {
                        my @allFiles    = map { "$stagedir/$_" } @files;
                        my @allSigFiles = grep { -e $_ } map { "$stagedir/$_.sig" } @files;

                        UBOS::Utils::deleteFile( @allFiles, @allSigFiles );

                        push @$removedFiles, @files;
                    }
                    $unstaged->{$packageName} = $uXConfigData->{$packageName};
                }
            }
        }
    }

    $run->setOutput( {
            'unstaged-packages' => $unstaged,
            'removed-files'     => $removedFiles
    } );

    if( %$unstaged ) {
        return SUCCESS;
    } else {
        return DONE_NOTHING;
    }
}

1;

