#!/usr/bin/perl
#
# Stage the most recent packages in a stage directory
#
# Copyright (C) 2014 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::Stage;

use base qw( Macrobuild::Task );
use fields qw( arch upconfigs usconfigs sourcedir stagedir dbfile dbSignKey releaseTimeStamp );

use Macrobuild::Task;
use UBOS::Logging;
use UBOS::Macrobuild::PacmanDbFile;
use UBOS::Macrobuild::Utils;
use UBOS::Utils;

##
# @Overridden
sub runImpl {
    my $self = shift;
    my $run  = shift;

    my $in = $run->getInput();

    # Change in algorithm. Instead of looking at what the previous task
    # passed in (which is brittle in case of errors), we look at what
    # files there are in the relevant directories

    my @addedPackageFiles = ();
    if( $self->{usconfigs} ) {
        my $usConfigs = $self->{usconfigs}->configs( $self );

        foreach my $repoName ( sort keys %$usConfigs ) { # make predictable sequence
            my $usConfig = $usConfigs->{$repoName};
            my $packages = $usConfig->packages();

            if( $packages ) {
                $self->_processPackages( $repoName, $packages, \@addedPackageFiles );
            }
        }
    }
    if( $self->{upconfigs} ) {
        my $upConfigs = $self->{upconfigs}->configs( $self );

        foreach my $repoName ( sort keys %$upConfigs ) { # make predictable sequence
            my $upConfig = $upConfigs->{$repoName};
            my $packages = $upConfig->packages();

            if( $packages ) {
                $self->_processPackages( $repoName, $packages, \@addedPackageFiles );
            }
        }
    }

    if( @addedPackageFiles ) {
        my $dbFile           = UBOS::Macrobuild::PacmanDbFile->new( $self->getProperty( 'dbfile' ));
        my $dbSignKey        = $self->getPropertyOrDefault( 'dbSignKey', undef );
        my $releaseTimeStamp = $self->getProperty( 'releaseTimeStamp' );

        if( $releaseTimeStamp ) {
            $releaseTimeStamp = UBOS::Utils::lenientRfc3339string2time( $releaseTimeStamp );
        }

        if( $dbFile->addPackages( $dbSignKey, \@addedPackageFiles ) == -1 ) {
            return FAIL;
        }
        if( $dbFile->createTimestampedCopy( $releaseTimeStamp ) == -1 ) {
            return FAIL;
        }

        $run->setOutput( {
                'added-package-files' => \@addedPackageFiles,
        } );
        return SUCCESS;

    } else {
        return DONE_NOTHING;
    }
}

##
# Perform the actual work
# $repoName: name of the current repo
# @$packages: the packages to stage
# @$addedPackageFiles: the actually staged files
sub _processPackages {
    my $self              = shift;
    my $repoName          = shift;
    my $packages          = shift;
    my $addedPackageFiles = shift;

    my $arch      = $self->getProperty( 'arch' );
    my $sourceDir = $self->getProperty( 'sourcedir' );
    my $stageDir  = $self->getProperty( 'stagedir' );

    UBOS::Macrobuild::Utils::ensureDirectories( $stageDir );

    foreach my $package ( keys %$packages ) {
        my $packageSourceDir = "$sourceDir/$repoName";
        if( $package eq '.' ) {
            $package = $repoName; # special convention
        } else {
             $packageSourceDir .= "/$package";
        }

        my @builtPackages  = UBOS::Macrobuild::PackageUtils::packageVersionsInDirectory( $package, $packageSourceDir, $arch );
        my @stagedPackages = UBOS::Macrobuild::PackageUtils::packageVersionsInDirectory( $package, $stageDir, $arch );
        if( @builtPackages ) {
            my $mostRecentBuiltPackage = UBOS::Macrobuild::PackageUtils::mostRecentPackageVersion( @builtPackages );
            trace( 'Found in', $packageSourceDir, 'built packages:', @builtPackages );
            trace( 'Most recent:', $mostRecentBuiltPackage );

            my $updateRequired = 0;

            if( @stagedPackages ) {
                my $mostRecentStagedPackage = UBOS::Macrobuild::PackageUtils::mostRecentPackageVersion( @stagedPackages );
                if( UBOS::Macrobuild::PackageUtils::comparePackageFileNamesByVersion( $mostRecentBuiltPackage, $mostRecentStagedPackage ) > 0 ) {
                    trace( 'Update required:', $mostRecentBuiltPackage, "($packageSourceDir) vs", $mostRecentStagedPackage, "($stageDir)" );
                    $updateRequired = 1;
                }
            } else {
                trace( 'No staged package found in', $stageDir, 'for', $package, "(built in $packageSourceDir)" );
                $updateRequired = 1;
            }

            if( $updateRequired ) {
                my $stagedPackage = "$stageDir/$mostRecentBuiltPackage";
                if( -e "$packageSourceDir/$mostRecentBuiltPackage.sig" ) {
                    UBOS::Utils::myexec( "cp '$packageSourceDir/$mostRecentBuiltPackage' '$stagedPackage'" );
                    UBOS::Utils::myexec( "cp '$packageSourceDir/$mostRecentBuiltPackage.sig' '$stagedPackage.sig'" );
                } else {
                    warning( 'No .sig file for package, not staging:', '$packageSourceDir/$mostRecentBuiltPackage' );
                }
                push @$addedPackageFiles, $stagedPackage;
                trace( "Staged:", $stagedPackage );
            }

        } else {
            warning( 'No built packages found in', $packageSourceDir );
        }
    }
}

1;


