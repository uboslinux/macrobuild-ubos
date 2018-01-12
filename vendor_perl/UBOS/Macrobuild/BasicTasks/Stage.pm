#!/usr/bin/perl
#
# Stage downloaded packages in a stage directory
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

    unless( exists( $in->{'new-packages'} )) {
        return DONE_NOTHING;
    }

    my $newPackages = $in->{'new-packages'};
    my $oldPackages = $in->{'old-packages'};
    my $staged      = {}; # Map<packageName,file[]>: Value is an array, so it is symmetric to Unstage,
                          # which might unstage several package versions at the same time

    my $destDir = $self->getProperty( 'stagedir' );

    UBOS::Macrobuild::Utils::ensureDirectories( $destDir );

    if( %$newPackages ) {
        foreach my $uXConfigName ( sort keys %$newPackages ) {
            my $uXConfigData = $newPackages->{$uXConfigName};

            foreach my $packageName ( sort keys %$uXConfigData ) {
                my $fileName = $uXConfigData->{$packageName};

                my $localFileName = $fileName;
                $localFileName =~ s!.*/!!;

                UBOS::Utils::myexec( "cp '$fileName' '$destDir/'" );
                if( -e "$fileName.sig" ) {
                    UBOS::Utils::myexec( "cp '$fileName.sig' '$destDir/'" );
                }

                $staged->{$packageName} = "$destDir/$localFileName";
                trace( "Staged:", $staged->{$packageName} );
            }
        }
    }
    if( defined( $oldPackages ) && %$oldPackages ) {
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

