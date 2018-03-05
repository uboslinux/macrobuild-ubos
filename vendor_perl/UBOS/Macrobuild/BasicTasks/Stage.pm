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
use fields qw( stagedir );

use Macrobuild::Task;
use UBOS::Logging;
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


    my $destDir = $self->getProperty( 'stagedir' );

    UBOS::Macrobuild::Utils::ensureDirectories( $destDir );


        foreach my $repoName ( sort keys %$oldPackages ) {
            my $repoData = $oldPackages->{$repoName};

            foreach my $packageName ( sort keys %$repoData ) {
                my $fileName = $repoData->{$packageName};

                my $localFileName = $fileName;
                $localFileName =~ s!.*/!!;

                unless( -e "$destDir/$localFileName" ) {
                    UBOS::Utils::myexec( "cp '$fileName' '$destDir/'" );
                    if( -e "$fileName.sig" ) {
                        UBOS::Utils::myexec( "cp '$fileName.sig' '$destDir/'" );
                    }

                    $staged->{$packageName} = "$destDir/$localFileName";
                    trace( "Staged again:", $staged->{$packageName} );
                }
            }
        }



#!/usr/bin/perl
#
# Checks PKGBUILD's pkgver against version of built packages
#
# Copyright (C) 2018 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::ComparePkgver;

use base qw( Macrobuild::Task );
use fields qw( arch branch sourcedir stagedir usconfigs db );

use Macrobuild::Task;
use UBOS::Logging;
use UBOS::Macrobuild::PackageUtils;

##
# @Overrides
sub runImpl {
    my $self = shift;
    my $run  = shift;

    my $arch      = $self->getProperty( 'arch' );
    my $sourceDir = $self->getProperty( 'sourcedir' );
    my $stageDir  = $self->getProperty( 'stagedir' );

    my $usConfigs = $self->{usconfigs}->configs( $self );
    unless( $usConfigs ) {
        return FAIL;
    }

    my $missingPackages      = {};
    my $wrongVersionPackages = {};

    foreach my $repoName ( sort keys %$usConfigs ) { # make predictable sequence
        my $usConfig        = $usConfigs->{$repoName};
        my $sourceSourceDir = "$sourceDir/$repoName";

        my $packages = $usConfig->packages();
        foreach my $package ( keys %$packages ) {
            my $sourceDir = $sourceSourceDir;
            if( '.' eq $package ) {
                # special convention
                $package = $repoName;
            } else {
                $sourceDir = "$sourceDir/$package";
            }

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

                if( @updateRequired ) {                    
                    UBOS::Utils::myexec( "cp '$sourceDir/$mostRecentBuiltPackage' '$stageDir/'" );
                    if( -e "$sourceDir/$mostRecentBuiltPackage.sig" ) {
                        UBOS::Utils::myexec( "cp '$sourceDir/$mostRecentBuiltPackage.sig' '$stageDir/'" );
                    }

                    $staged->{$package} = "$stageDir/$mostRecentBuiltPackage";
                    trace( "Staged:", $staged->{$package} );
                }

            } else {
                warning( 'No built packages found in', $sourceDir );
            }
        }
    }

    $run->setOutput( {
            'staged-packages' => $staged
    } );

    if( %$staged ) {
        return SUCCESS;
    } else {
        return DONE_NOTHING;
    }
}

1;

