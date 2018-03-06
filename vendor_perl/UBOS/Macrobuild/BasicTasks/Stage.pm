#!/usr/bin/perl
#
# Stage the most recen packages in a stage directory
#
# Copyright (C) 2014 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::Stage;

use base qw( Macrobuild::Task );
use fields qw( arch packages sourcedir stagedir dbfile dbSignKey );

use Macrobuild::Task;
use UBOS::Logging;
use UBOS::Macrobuild::PacmanDbFile;
use UBOS::Macrobuild::Utils;

##
# @Overridden
sub runImpl {
    my $self = shift;
    my $run  = shift;

    my $in = $run->getInput();

    # Change in algorithm. Instead of looking at what the previous task
    # passed in (which is brittle in case of errors), we look at what
    # files there are in the relevant directories

    my $arch      = $self->getProperty( 'arch' );
    my $packages  = $self->getProperty( 'packages' );
    my $sourceDir = $self->getProperty( 'sourcedir' );
    my $stageDir  = $self->getProperty( 'stagedir' );
    my $dbSignKey = $self->getPropertyOrDefault( 'dbSignKey', undef );
    my $dbFile    = UBOS::Macrobuild::PacmanDbFile->new( $self->getProperty( 'dbfile' ));

    UBOS::Macrobuild::Utils::ensureDirectories( $stageDir );

    my @addedPackageFiles = ();

    foreach my $package ( @$packages ) {
        my @builtPackages  = UBOS::Macrobuild::PackageUtils::packageVersionsInDirectory( $package, $sourceDir, $arch );
        my @stagedPackages = UBOS::Macrobuild::PackageUtils::packageVersionsInDirectory( $package, $stageDir, $arch );
        if( @builtPackages ) {
            my $mostRecentBuiltPackage = UBOS::Macrobuild::PackageUtils::mostRecentPackageVersion( @builtPackages );
            trace( 'Found in', $sourceDir, 'built packages:', @builtPackages );
            trace( 'Most recent:', $mostRecentBuiltPackage );

            my $updateRequired = 0;

            if( @stagedPackages ) {
                my $mostRecentStagedPackage = UBOS::Macrobuild::PackageUtils::mostRecentPackageVersion( @stagedPackages );
                if( UBOS::Macrobuild::PackageUtils::comparePackageFileNamesByVersion( $mostRecentBuiltPackage, $mostRecentStagedPackage ) > 0 ) {
                    trace( 'Update required:', $mostRecentBuiltPackage, "($sourceDir) vs", $mostRecentStagedPackage, "($stageDir)" );
                    $updateRequired = 1;
                }
            } else {
                trace( 'No staged package found in', $stageDir, 'for', $package, "(built in $sourceDir)" );
                $updateRequired = 1;
            }

            if( $updateRequired ) {
                my $stagedPackage = "$stageDir/$mostRecentBuiltPackage";
                UBOS::Utils::myexec( "cp '$sourceDir/$mostRecentBuiltPackage' '$stagedPackage'" );
                if( -e "$sourceDir/$mostRecentBuiltPackage.sig" ) {
                    UBOS::Utils::myexec( "cp '$sourceDir/$mostRecentBuiltPackage.sig' '$stagedPackage.sig'" );
                }
                push @addedPackageFiles, $stagedPackage;
                trace( "Staged:", $stagedPackage );
            }

        } else {
            warning( 'No built packages found in', $sourceDir );
        }
    }
    if( $dbFile->addPackages( $dbSignKey, \@addedPackageFiles ) == -1 ) {
        return FAIL;
    }

    $run->setOutput( {
            'added-package-files' => \@addedPackageFiles,
    } );

    if( @addedPackageFiles ) {
        return SUCCESS;
    } else {
        return DONE_NOTHING;
    }
}

1;


