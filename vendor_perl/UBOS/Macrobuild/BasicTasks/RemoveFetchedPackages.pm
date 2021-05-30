#!/usr/bin/perl
#
# Remove one or more packages fetched from Arch and marked as such.
#
# Copyright (C) 2016 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::RemoveFetchedPackages;

use base qw( Macrobuild::Task );
use fields qw( arch upconfigs downloaddir );

use Macrobuild::Task;
use UBOS::Macrobuild::PackageUtils;

##
# Run this task.
# $run: the inputs, outputs, settings and possible other context info for the run
sub runImpl {
    my $self = shift;
    my $run  = shift;

    my $downloadDir = $self->getProperty( 'downloaddir' );
    my $arch        = $self->getProperty( 'arch' );

    my $upConfigs = $self->{upconfigs}->configs( $self );
    unless( $upConfigs ) {
        return FAIL;
    }

    my $removedPackages = {};

    my $ok = 1;
    foreach my $repoName ( sort keys %$upConfigs ) { # make predictable sequence
        my $upConfig = $upConfigs->{$repoName};

        my $removePackages = $upConfig->removePackages;
        unless( $removePackages ) {
            next;
        }

        foreach my $removePackage ( keys %$removePackages ) {
            if( '.' eq $removePackage ) {
                $removePackage = $repoName;
            }

            my @files = UBOS::Macrobuild::PackageUtils::packageVersionsInDirectory( $removePackage, $downloadDir, $arch );

            if( @files ) {
                my @allFiles    = map { "$downloadDir/$_" } @files;
                my @allSigFiles = grep { -e $_ } map { "$downloadDir/$_.sig" } @files;

                UBOS::Utils::deleteFile( @allFiles, @allSigFiles );
            }

            $removedPackages->{$repoName}->{$removePackage} = \@files;
        }
    }

    $run->setOutput( {
            'removed-packages' => $removedPackages
    } );

    if( !$ok ) {
        return FAIL;

    } elsif( keys %$removedPackages ) {
        return SUCCESS;
    } else {
        return DONE_NOTHING;
    }
}

1;
