#!/usr/bin/perl
#
# Determine which packages can be promoted from one db in
# one channel to another.
#
# Copyright (C) 2014 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Macrobuild::BasicTasks::DeterminePromotablePackages;

use base qw( Macrobuild::Task );
use fields qw( arch channel upconfigs usconfigs fromDb toDb );

use File::Spec;
use Macrobuild::Task;
use UBOS::Logging;
use UBOS::Macrobuild::PackageUtils;
use UBOS::Utils;

##
# @Overridable
sub runImpl {
    my $self = shift;
    my $run  = shift;

    my $arch    = $self->getProperty( 'arch' );
    my $channel = $self->getProperty( 'channel' );

    my $fromDb = $self->getProperty( 'fromDb' );
    my $toDb   = $self->getProperty( 'toDb' );

    my $upConfigs = $self->{upconfigs}->configs( $self );
    my $usConfigs = $self->{usconfigs}->configs( $self );

    unless( $upConfigs ) {
        return FAIL;
    }
    unless( $usConfigs ) {
        return FAIL;
    }

    my $newPackages = {};
    my $oldPackages = {};

    foreach my $upConfigName ( sort keys %$upConfigs ) { # make predictable sequence
        my $upConfig = $upConfigs->{$upConfigName};
        my $packages = $upConfig->packages();

        unless( $packages ) {
            next;
        }

        foreach my $packageName ( sort keys %$packages ) {
            my $packageInfo = $packages->{$packageName};

            my @candidatePackages = UBOS::Macrobuild::PackageUtils::packageVersionsInDirectory( $packageName, $fromDb, $arch );
            my $toPromote;
            if( exists( $packageInfo->{$channel}->{version} )) {
                if( exists( $packageInfo->{$channel}->{release} )) {
                    $toPromote = UBOS::Macrobuild::PackageUtils::packageVersionNoLaterThan( $packageInfo->{$channel}, @candidatePackages );

                } else {
                    error( 'Cannot determine whether to promote', $packageName, ': spec unclear for channel', $channel );
                }
            } else {
                $toPromote = UBOS::Macrobuild::PackageUtils::mostRecentPackageVersion( @candidatePackages );
            }
            if( defined( $toPromote )) {
                if( -e "$toDb/$toPromote" ) {
                    $oldPackages->{$upConfigName}->{$packageName} = "$fromDb/$toPromote";
                } else {
                    $newPackages->{$upConfigName}->{$packageName} = "$fromDb/$toPromote";
                }
            }
        }
    }

    # usconfig uses very similar code to upconfig
    foreach my $usConfigName ( sort keys %$usConfigs ) {
        my $usConfig = $usConfigs->{$usConfigName};
        my $packages = $usConfig->packages();

        unless( $packages ) {
            next;
        }

        foreach my $packageName ( sort keys %$packages ) {
            my $packageInfo = $packages->{$packageName};

            if( '.' eq $packageName ) {
                $packageName = $usConfig->name;
            }

            my @candidatePackages = UBOS::Macrobuild::PackageUtils::packageVersionsInDirectory( $packageName, $fromDb, $arch );
            my $toPromote;
            if( exists( $packageInfo->{$channel}->{version} )) {
                if( exists( $packageInfo->{$channel}->{release} )) {
                    $toPromote = UBOS::Macrobuild::PackageUtils::packageVersionNoLaterThan( $packageInfo->{$channel}, @candidatePackages );

                } else {
                    error( 'Cannot determine whether to promote', $packageName, ': spec unclear for channel', $channel );
                }
            } else {
                $toPromote = UBOS::Macrobuild::PackageUtils::mostRecentPackageVersion( @candidatePackages );
            }
            if( defined( $toPromote )) {
                if( -e "$toDb/$toPromote" ) {
                    $oldPackages->{$usConfigName}->{$packageName} = "$fromDb/$toPromote";
                } else {
                    $newPackages->{$usConfigName}->{$packageName} = "$fromDb/$toPromote";
                }
            }
        }
    }

    $run->setOutput( {
            'new-packages' => $newPackages,
            'old-packages' => $oldPackages
    } );

    if( keys %$newPackages ) {
        return SUCCESS;
    } else {
        return DONE_NOTHING;
    }
}

1;

