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
use fields qw( arch stagedir dbfile dbSignKey );

use Macrobuild::Task;
use UBOS::Macrobuild::PacmanDbFile;
use UBOS::Macrobuild::Utils;
use UBOS::Logging;
use UBOS::Utils;

##
# @Overridden
sub runImpl {
    my $self = shift;
    my $run  = shift;

    my $in = $run->getInput();

    my $ret             = SUCCESS;
    my @removedPackages = ();

    if( exists( $in->{'removed-packages'} )) {

        my $removedPackages = $in->{'removed-packages'};
        if( %$removedPackages ) {

            my $stagedir  = $self->getProperty( 'stagedir' );
            my $arch      = $self->getProperty( 'arch' );
            my $dbFile    = UBOS::Macrobuild::PacmanDbFile->new( $self->getProperty( 'dbfile' ));
            my $dbSignKey = $self->getPropertyOrDefault( 'dbSignKey', undef );

            UBOS::Macrobuild::Utils::ensureDirectories( $stagedir );

            foreach my $uXConfigName ( sort keys %$removedPackages ) {
                my $uXConfigData = $removedPackages->{$uXConfigName};

                foreach my $packageName ( sort keys %$uXConfigData ) {

                    my @files = UBOS::Macrobuild::PackageUtils::packageVersionsInDirectory( $packageName, $stagedir, $arch );
                    if( @files ) {
                        # We only take the package out of the repository index, if at least one file existed; reasonable?
                        my @allFiles    = map { "$stagedir/$_" } @files;
                        my @allSigFiles = grep { -e $_ } map { "$stagedir/$_.sig" } @files;

                        UBOS::Utils::deleteFile( @allFiles, @allSigFiles );

                        if( $dbFile->removePackages( $dbSignKey, [ $packageName ] ) == -1 ) {
                            $ret = FAIL;
                        } else {
                            push @removedPackages, @allFiles;
                        }
                    }
                }
            }
        }
    }

    if( $ret == FAIL ) {
        return $ret;
    }

    $run->setOutput( {
        'removed-packages' => \@removedPackages
    } );

    if( @removedPackages ) {
        return SUCCESS;
    } else {
        return DONE_NOTHING;
    }
}

1;

