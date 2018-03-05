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

    my $ok = 1;
    foreach my $repoName ( sort keys %$usConfigs ) { # make predictable sequence
        my $usConfig = $usConfigs->{$repoName};
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

                if( @stagedPackages ) {
                    my $mostRecentStagedPackage = UBOS::Macrobuild::PackageUtils::mostRecentPackageVersion( @stagedPackages );
                    if( UBOS::Macrobuild::PackageUtils::comparePackageFileNamesByVersion( $mostRecentBuiltPackage, $mostRecentStagedPackage )) {
                        trace( 'Most recent built and staged package versions differ:', $mostRecentBuiltPackage, "($sourceDir) vs", $mostRecentStagedPackage, "($stageDir)" );
                        $wrongVersionPackages->{$repoName}->{$package} = {
                                'built'              => \@builtPackages,
                                'most-recent-built'  => $mostRecentBuiltPackage,
                                'staged'             => \@stagedPackages,
                                'most-recent-staged' => $mostRecentStagedPackage
                        };
                        $ok = 0;
                    }
                } else {
                    trace( 'No staged package found in', $stageDir, 'for', $package, "(built in $sourceDir)" );
                    $missingPackages->{$repoName}->{$package} = {
                            'built'              => \@builtPackages,
                            'most-recent-built'  => $mostRecentBuiltPackage
                    };
                    $ok = 0;
                }

            } else {
                warning( 'No built packages found in', $sourceDir );
            }
        }
    }

    $run->setOutput( {
            'wrong-versions' => $wrongVersionPackages,
            'missing'        => $missingPackages
    } );

    if( $ok ) {
        return SUCCESS();
    } else {
        return FAIL();
    }
}

1;
